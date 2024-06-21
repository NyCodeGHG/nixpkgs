use std::{
    collections::{BTreeMap, HashMap},
    env,
    io::BufReader,
};

use anyhow::Context;
use log::{debug, error};
use rayon::iter::{IntoParallelRefIterator, ParallelIterator};
use serde::{Deserialize, Serialize};
use url::Url;

use crate::{
    lockfile::{NpmLockfile, NpmLockfileV1, NpmPackage},
    parse::{check_for_missing_fields, lock::Hash},
    util,
};

#[derive(Debug, Deserialize, Serialize)]
pub struct LockfileOverride {
    resolved: Option<String>,
    integrity: Option<String>,
}

/// tries to apply all lockfile overrides, read from the environment to the given lockfile.
///
/// returns true if the lockfile has been modified.
pub fn apply_lockfile_overrides(lock: &mut NpmLockfile) -> anyhow::Result<bool> {
    let mut modified = false;
    if let Ok(overrides_file) = env::var("lockfileOverridesPath") {
        let mut file = BufReader::new(std::fs::File::open(overrides_file)?);
        let overrides: HashMap<String, LockfileOverride> = serde_json::from_reader(&mut file)
            .context("Failed to deserialize lockfile overrides.")?;
        for (name, or) in overrides {
            apply_override(&name, lock, or)?;
            modified = true;
        }
    }
    Ok(modified)
}

pub fn apply_override(
    package_name: &str,
    lockfile: &mut NpmLockfile,
    o: LockfileOverride,
) -> anyhow::Result<()> {
    match lockfile {
        NpmLockfile::V1(lock) => apply_override_to_v1_package(package_name, lock, o),
        NpmLockfile::V2(lock) => {
            lock.dependencies.clear();
            apply_override_to_v2_package(package_name, &mut lock.packages, o)
        }
        NpmLockfile::V3(lock) => apply_override_to_v2_package(package_name, &mut lock.packages, o),
    }
}

fn apply_override_to_v1_package(
    package_name: &str,
    lock: &mut NpmLockfileV1,
    o: LockfileOverride,
) -> anyhow::Result<()> {
    let dependency = lock
        .dependencies
        .get_mut(package_name)
        .with_context(|| format!("Couldn't find the dependency {}", package_name))?;
    if let Some(resolved) = o.resolved {
        debug!("Patching resolved in {} to {}", package_name, resolved);
        dependency.resolved = Some(resolved);
    }
    if let Some(integrity) = o.integrity {
        debug!("Patching integrity in {} to {}", package_name, integrity);
        dependency.integrity = Some(integrity);
    }
    Ok(())
}

fn apply_override_to_v2_package(
    package_name: &str,
    dependencies: &mut BTreeMap<String, NpmPackage>,
    o: LockfileOverride,
) -> anyhow::Result<()> {
    let dependency = dependencies
        .get_mut(package_name)
        .with_context(|| format!("Couldn't find the dependency {}", package_name))?;
    if let Some(resolved) = o.resolved {
        debug!("Patching resolved in {} to {}", package_name, resolved);
        dependency.resolved = Some(resolved);
    }
    if let Some(integrity) = o.integrity {
        debug!("Patching integrity in {} to {}", package_name, integrity);
        dependency.integrity = Some(integrity);
    }
    Ok(())
}

pub fn generate_missing_overrides(
    lock: &NpmLockfile,
) -> anyhow::Result<BTreeMap<String, LockfileOverride>> {
    let missing = check_for_missing_fields(&lock)?;
    let result: anyhow::Result<Vec<(String, PackageData)>> = missing
        .par_iter()
        .map(|package| {
            let name = package.name.as_ref().unwrap();
            let version = package.version.as_ref().unwrap();
            let data = fetch_npm_data(name, version)?;
            Ok((name.clone(), data))
        })
        .collect();

    let mut result = result?;

    result.sort_by(|a, b| a.0.cmp(&b.0));

    let map = BTreeMap::from_iter(result.into_iter().map(|(name, data)| {
        (
            name,
            LockfileOverride {
                integrity: Some(data.integrity),
                resolved: Some(data.resolved),
            },
        )
    }));

    Ok(map)
}

/// recursively extracts the name of a package from its full path
/// e.g. node_modules/axios -> axios
fn extract_package_name(path: &str) -> &str {
    if let Some(index) = path.find("node_modules/") {
        extract_package_name(&path["node_modules/".len() + index..])
    } else {
        path
    }
}

fn fetch_npm_data(package: &str, version: &str) -> anyhow::Result<PackageData> {
    let name = extract_package_name(package);
    let url = &Url::parse(&format!("https://registry.npmjs.com/{name}/{version}"))?;
    debug!("Fetching url {url}");
    let npm_raw_data = util::get_url_body_with_retry(url)?;
    let npm_data: NpmRegistryData = serde_json::from_slice(&npm_raw_data).with_context(|| {
        format!("Failed to deserialize npm's response while fetching {name}@{version}.")
    })?;
    Ok(PackageData {
        integrity: npm_data.dist.integrity,
        resolved: npm_data.dist.tarball,
    })
}

#[derive(Deserialize)]
struct NpmRegistryData {
    dist: NpmRegistryDataDist,
}

#[derive(Deserialize)]
struct NpmRegistryDataDist {
    integrity: String,
    tarball: String,
}

struct PackageData {
    integrity: String,
    resolved: String,
}
