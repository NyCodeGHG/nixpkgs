use anyhow::{anyhow, bail, Context};
use rayon::{prelude::*, slice::ParallelSliceMut};
use serde::{
    de::{self, Visitor},
    Deserialize, Deserializer,
};
use std::{
    cmp::Ordering,
    collections::{HashMap, HashSet},
    fmt,
    str::FromStr,
};
use url::Url;

use crate::util::get_url_body_with_retry;

pub(super) fn packages(content: &str) -> anyhow::Result<Vec<Package>> {
    let lockfile: Lockfile = serde_json::from_str(content)?;

    let mut packages = match lockfile.version {
        1 => {
            let initial_url = get_initial_url()?;

            lockfile
                .dependencies
                .map(|p| to_new_packages(p, &initial_url))
                .transpose()?
        }
        2 | 3 => lockfile.packages.map(|pkgs| {
            pkgs.into_par_iter()
                .filter(|(n, _)| !n.is_empty())
                .filter(|(_, p)| match p.resolved {
                    None => true,
                    Some(UrlOrString::Url(_)) => true,
                    _ => false,
                })
                .filter(|(_, p)| p.version.is_some())
                .map(|(n, p)| {
                    let mut package = Package { name: Some(n), ..p };
                    fetch_integrity(&mut package).unwrap();
                    package
                })
                .filter(|p| p.integrity.is_some() && p.resolved.is_some())
                .collect()
        }),
        _ => bail!(
            "We don't support lockfile version {}, please file an issue.",
            lockfile.version
        ),
    }
    .expect("lockfile should have packages");

    packages.par_sort_by(|x, y| {
        x.resolved
            .partial_cmp(&y.resolved)
            .expect("resolved should be comparable")
            .then(
                // v1 lockfiles can contain multiple references to the same version of a package, with
                // different integrity values (e.g. a SHA-1 and a SHA-512 in one, but just a SHA-512 in another)
                y.integrity
                    .partial_cmp(&x.integrity)
                    .expect("integrity should be comparable"),
            )
    });

    packages.dedup_by(|x, y| x.resolved == y.resolved);

    Ok(packages)
}

#[derive(Deserialize)]
struct Lockfile {
    #[serde(rename = "lockfileVersion")]
    version: u8,
    dependencies: Option<HashMap<String, OldPackage>>,
    packages: Option<HashMap<String, Package>>,
}

#[derive(Deserialize)]
struct OldPackage {
    version: UrlOrString,
    #[serde(default)]
    bundled: bool,
    resolved: Option<UrlOrString>,
    integrity: Option<HashCollection>,
    dependencies: Option<HashMap<String, OldPackage>>,
}

#[derive(Debug, Deserialize, PartialEq, Eq)]
pub(super) struct Package {
    #[serde(default)]
    pub(super) name: Option<String>,
    pub(super) version: Option<UrlOrString>,
    pub(super) resolved: Option<UrlOrString>,
    pub(super) integrity: Option<HashCollection>,
}

#[derive(Debug, Deserialize, PartialEq, Eq, PartialOrd, Ord, Clone)]
#[serde(untagged)]
pub(super) enum UrlOrString {
    Url(Url),
    String(String),
}

impl fmt::Display for UrlOrString {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            UrlOrString::Url(url) => url.fmt(f),
            UrlOrString::String(string) => string.fmt(f),
        }
    }
}

#[derive(Debug, PartialEq, Eq, Clone)]
pub struct HashCollection(HashSet<Hash>);

impl HashCollection {
    pub fn from_str(s: impl AsRef<str>) -> anyhow::Result<HashCollection> {
        let hashes = s
            .as_ref()
            .split_ascii_whitespace()
            .map(Hash::new)
            .collect::<anyhow::Result<_>>()?;

        Ok(HashCollection(hashes))
    }

    pub fn into_best(self) -> Option<Hash> {
        self.0.into_iter().max()
    }
}

impl PartialOrd for HashCollection {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        let lhs = self.0.iter().max()?;
        let rhs = other.0.iter().max()?;

        lhs.partial_cmp(rhs)
    }
}

impl<'de> Deserialize<'de> for HashCollection {
    fn deserialize<D>(deserializer: D) -> Result<HashCollection, D::Error>
    where
        D: Deserializer<'de>,
    {
        deserializer.deserialize_string(HashCollectionVisitor)
    }
}

struct HashCollectionVisitor;

impl<'de> Visitor<'de> for HashCollectionVisitor {
    type Value = HashCollection;

    fn expecting(&self, formatter: &mut fmt::Formatter) -> fmt::Result {
        formatter.write_str("a single SRI hash or a collection of them (separated by spaces)")
    }

    fn visit_str<E>(self, value: &str) -> Result<HashCollection, E>
    where
        E: de::Error,
    {
        HashCollection::from_str(value).map_err(E::custom)
    }
}

#[derive(Clone, Debug, Deserialize, PartialEq, Eq, Hash)]
pub struct Hash(String);

// Hash algorithms, in ascending preference.
const ALGOS: &[&str] = &["sha1", "sha512"];

impl Hash {
    fn new(s: impl AsRef<str>) -> anyhow::Result<Hash> {
        let algo = s
            .as_ref()
            .split_once('-')
            .ok_or_else(|| anyhow!("expected SRI hash, got {:?}", s.as_ref()))?
            .0;

        if ALGOS.iter().any(|&a| algo == a) {
            Ok(Hash(s.as_ref().to_string()))
        } else {
            Err(anyhow!("unknown hash algorithm {algo:?}"))
        }
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl fmt::Display for Hash {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.as_str().fmt(f)
    }
}

impl PartialOrd for Hash {
    fn partial_cmp(&self, other: &Hash) -> Option<Ordering> {
        let lhs = self.0.split_once('-')?.0;
        let rhs = other.0.split_once('-')?.0;

        ALGOS
            .iter()
            .position(|&s| lhs == s)?
            .partial_cmp(&ALGOS.iter().position(|&s| rhs == s)?)
    }
}

impl Ord for Hash {
    fn cmp(&self, other: &Hash) -> Ordering {
        self.partial_cmp(other).unwrap()
    }
}

#[allow(clippy::case_sensitive_file_extension_comparisons)]
fn to_new_packages(
    old_packages: HashMap<String, OldPackage>,
    initial_url: &Url,
) -> anyhow::Result<Vec<Package>> {
    let mut new = Vec::new();

    for (name, mut package) in old_packages {
        // In some cases, a bundled dependency happens to have the same version as a non-bundled one, causing
        // the bundled one without a URL to override the entry for the non-bundled instance, which prevents the
        // dependency from being downloaded.
        if package.bundled {
            continue;
        }

        if let UrlOrString::Url(v) = &package.version {
            for (scheme, host) in [
                ("github", "github.com"),
                ("bitbucket", "bitbucket.org"),
                ("gitlab", "gitlab.com"),
            ] {
                if v.scheme() == scheme {
                    package.version = {
                        let mut new_url = initial_url.clone();

                        new_url.set_host(Some(host))?;

                        if v.path().ends_with(".git") {
                            new_url.set_path(v.path());
                        } else {
                            new_url.set_path(&format!("{}.git", v.path()));
                        }

                        new_url.set_fragment(v.fragment());

                        UrlOrString::Url(new_url)
                    };

                    break;
                }
            }
        }

        let (resolved, integrity) = match package.version {
            UrlOrString::Url(_) => (package.version, package.integrity),
            UrlOrString::String(version) => match package.resolved {
                Some(resolved) => (resolved, package.integrity),
                None => {
                    println!("{name}@{version}: Fetching integrity from registry");
                    let metadata = get_registry_metadata(&name, &version)?;
                    (
                        UrlOrString::Url(metadata.dist.tarball),
                        Some(metadata.dist.integrity),
                    )
                }
            },
        };

        new.push(Package {
            name: Some(name),
            version: None,
            resolved: Some(resolved),
            integrity,
        });

        if let Some(dependencies) = package.dependencies {
            new.append(&mut to_new_packages(dependencies, initial_url)?);
        }
    }

    Ok(new)
}

fn get_initial_url() -> anyhow::Result<Url> {
    Url::parse("git+ssh://git@a.b").context("initial url should be valid")
}

const NODE_MODULES_LEN: usize = "node_modules/".len();

fn extract_name_from_path(path: &str) -> Option<&str> {
    let index = path.rfind("node_modules/")? + NODE_MODULES_LEN;
    Some(&path[index..])
}

fn fetch_integrity(package: &mut Package) -> anyhow::Result<()> {
    let Some(name) = package
        .name
        .as_ref()
        .and_then(|name| extract_name_from_path(name))
    else {
        return Ok(());
    };
    let Some(version) = &package.version else {
        // skip packages without a version
        return Ok(());
    };

    if let Some((resolved, integrity)) = match version {
        UrlOrString::Url(_) => None,
        UrlOrString::String(version) => match &package.resolved {
            Some(resolved) => Some((resolved.clone(), package.integrity.clone())),
            None => {
                println!("{name}@{version}: Fetching integrity from registry");
                let metadata = get_registry_metadata(&name, &version)?;
                Some((
                    UrlOrString::Url(metadata.dist.tarball),
                    Some(metadata.dist.integrity),
                ))
            }
        },
    } {
        package.resolved = Some(resolved);
        package.integrity = integrity;
    }

    Ok(())
}

#[derive(Deserialize)]
struct RegistryMetadata {
    dist: DistributionMetadata,
}

#[derive(Deserialize)]
struct DistributionMetadata {
    integrity: HashCollection,
    tarball: Url,
}

fn get_registry_metadata(package: &str, version: &str) -> anyhow::Result<RegistryMetadata> {
    let body = get_url_body_with_retry(&Url::from_str(
        format!("https://registry.npmjs.com/{package}/{version}").as_str(),
    )?)?;
    let metadata = serde_json::from_slice(&body)?;
    Ok(metadata)
}

#[cfg(test)]
mod tests {
    use crate::parse::lock::extract_name_from_path;

    use super::{
        get_initial_url, to_new_packages, Hash, HashCollection, OldPackage, Package, UrlOrString,
    };
    use std::{
        cmp::Ordering,
        collections::{HashMap, HashSet},
    };
    use url::Url;

    #[test]
    fn git_shorthand_v1() -> anyhow::Result<()> {
        let old = {
            let mut o = HashMap::new();
            o.insert(
                String::from("sqlite3"),
                OldPackage {
                    version: UrlOrString::Url(
                        Url::parse(
                            "github:mapbox/node-sqlite3#593c9d498be2510d286349134537e3bf89401c4a",
                        )
                        .unwrap(),
                    ),
                    bundled: false,
                    resolved: None,
                    integrity: None,
                    dependencies: None,
                },
            );
            o
        };

        let initial_url = get_initial_url()?;

        let new = to_new_packages(old, &initial_url)?;

        assert_eq!(new.len(), 1, "new packages map should contain 1 value");
        assert_eq!(new[0], Package {
            name: Some(String::from("sqlite3")),
            resolved: Some(UrlOrString::Url(Url::parse("git+ssh://git@github.com/mapbox/node-sqlite3.git#593c9d498be2510d286349134537e3bf89401c4a").unwrap())),
            version: None,
            integrity: None
        });

        Ok(())
    }

    #[test]
    fn hash_preference() {
        assert_eq!(
            Hash(String::from("sha1-foo")).partial_cmp(&Hash(String::from("sha512-foo"))),
            Some(Ordering::Less)
        );

        assert_eq!(
            HashCollection({
                let mut set = HashSet::new();
                set.insert(Hash(String::from("sha512-foo")));
                set.insert(Hash(String::from("sha1-bar")));
                set
            })
            .into_best(),
            Some(Hash(String::from("sha512-foo")))
        );
    }

    #[test]
    fn extract_name() {
        assert_eq!(
            Some("commander"),
            extract_name_from_path("html-minifier-terser/node_modules/commander")
        );
        assert_eq!(
            Some("@ampproject/remapping"),
            extract_name_from_path("node_modules/@ampproject/remapping")
        );
        assert_eq!(
            Some("which"),
            extract_name_from_path("phantomjs-prebuilt/node_modules/which")
        );
        assert_eq!(
            Some("yallist"),
            extract_name_from_path("node_modules/update-notifier/node_modules/yallist")
        )
    }
}
