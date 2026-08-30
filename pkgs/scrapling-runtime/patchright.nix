# Upstream note: patchright's GitHub source is NOT the release content — the real
# package is built by their release workflow, and nixpkgs carries a `broken = true`
# 1.58 for exactly that reason. The PyPI wheel is the real artifact and embeds the
# patched driver. The bundled FHS node never execs: the runtime wrapper sets
# PLAYWRIGHT_NODEJS_PATH to nixpkgs nodejs (honored natively by `_driver.py`).
{
  lib,
  buildPythonPackage,
  fetchPypi,
  greenlet,
  pyee,
}:

buildPythonPackage rec {
  format = "wheel";
  pname = "patchright";
  version = "1.62.2";

  src = fetchPypi {
    inherit pname version;
    format = "wheel";
    dist = "py3";
    python = "py3";
    abi = "none";
    platform = "manylinux1_x86_64";
    hash = "sha256-G5C2wxwWzo7ZzpMsFo//0Me0Us7dgz/vQnHmmJtWt70=";
  };

  dependencies = [
    greenlet
    pyee
  ];

  # Module attempts filesystem writes at import time (same as nixpkgs' playwright note).
  pythonImportsCheck = [ ];
  doCheck = false;

  meta = {
    description = "Undetected Python version of the Playwright automation library";
    homepage = "https://github.com/Kaliiiiiiiiii-Vinyzu/patchright-python";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
  };
}
