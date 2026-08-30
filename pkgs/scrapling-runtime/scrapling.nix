# The `ai` + `fetchers` extras of scrapling, flattened — everything the MCP
# server path needs. Deps resolve inside the packageOverrides scope of
# package.nix, so `mcp`, `patchright` pick up the overridden versions.
{
  lib,
  buildPythonPackage,
  fetchPypi,
  python,
  setuptools,
  # fetchers + core
  anyio,
  apify-fingerprint-datapoints,
  browserforge,
  click,
  cssselect,
  curl-cffi,
  lxml,
  mcp,
  msgspec,
  orjson,
  patchright,
  playwright,
  protego,
  tld,
  typing-extensions,
  w3lib,
  # ai extra
  markdownify,
}:

buildPythonPackage rec {
  pname = "scrapling";
  version = "0.4.15";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-ckBpAPQ3MWIJ3QXZhT2uBEIPHKsOEQcWBLtFiLbi9xM=";
  };

  # Metadata pins playwright>=1.62, but 1.61 (nixpkgs) is proven compatible
  # through executable_path; relax so the runtime-deps check passes.
  pythonRelaxDeps = [ "playwright" ];

  build-system = [ setuptools ];

  dependencies = [
    anyio
    apify-fingerprint-datapoints
    browserforge
    click
    cssselect
    curl-cffi
    lxml
    markdownify
    mcp
    msgspec
    orjson
    patchright
    playwright
    protego
    tld
    typing-extensions
    w3lib
  ];

  # `scrapling install` is a no-op by construction: Chromium comes from
  # nixpkgs via SCRAPLING_EXECUTABLE_PATH, and this marker silences the
  # check that would otherwise point at the apt-based install-deps path.
  postInstall = ''
    touch $out/${python.sitePackages}/scrapling/.scrapling_dependencies_installed
  '';

  pythonImportsCheck = [ ];
  doCheck = false;

  meta = {
    description = "Undetectable, Lightning-Fast, and Adaptive Web Scraping for Python";
    homepage = "https://github.com/D4Vinci/Scrapling";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
  };
}
