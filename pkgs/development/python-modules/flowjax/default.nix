{
  lib,
  buildPythonPackage,
  fetchFromGitHub,

  # build-system
  hatchling,

  # dependencies
  equinox,
  jax,
  jaxtyping,
  optax,
  paramax,
  tqdm,

  # tests
  beartype,
  numpyro,
  pytest-xdist,
  pytestCheckHook,
}:

buildPythonPackage rec {
  pname = "flowjax";
  version = "17.1.2";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "danielward27";
    repo = "flowjax";
    tag = "v${version}";
    hash = "sha256-NTP5QFJDe4tSAuHsQB4ZWyCcqLgW6uUaABfOG/TFgu0=";
  };

  build-system = [
    hatchling
  ];

  dependencies = [
    equinox
    jax
    jaxtyping
    optax
    paramax
    tqdm
  ];

  pythonImportsCheck = [ "flowjax" ];

  nativeCheckInputs = [
    beartype
    numpyro
    pytest-xdist
    pytestCheckHook
  ];

  meta = {
    description = "Distributions, bijections and normalizing flows using Equinox and JAX";
    homepage = "https://github.com/danielward27/flowjax";
    changelog = "https://github.com/danielward27/flowjax/releases/tag/v${version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ GaetanLepage ];
  };
}
