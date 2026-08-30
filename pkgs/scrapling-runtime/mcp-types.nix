# Pinned sibling of mcp 2.1.1 (`mcp-types==2.1.1`), not yet in nixpkgs.
# Plain fetchurl because fetchPypi cannot construct the underscore filename.
{
  lib,
  buildPythonPackage,
  fetchurl,
  hatchling,
  pydantic,
  typing-extensions,
  uv-dynamic-versioning,
}:

buildPythonPackage rec {
  pname = "mcp-types";
  version = "2.1.1";
  pyproject = true;

  src = fetchurl {
    url = "https://pypi.io/packages/source/m/mcp-types/mcp_types-2.1.1.tar.gz";
    hash = "sha256-d9y+SPunPMpxpnPyZGpfA3oBe3oKB6yJzsERMCiJDto=";
  };

  dependencies = [
    pydantic
    typing-extensions
  ];

  build-system = [
    hatchling
    uv-dynamic-versioning
  ];

  pythonImportsCheck = [ ];
  doCheck = false;

  meta = {
    description = "Model Context Protocol type definitions";
    homepage = "https://github.com/modelcontextprotocol/python-sdk";
    license = lib.licenses.mit;
  };
}
