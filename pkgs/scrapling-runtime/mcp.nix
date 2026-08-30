# mcp 2.1.1: scrapling imports `mcp.server.MCPServer`, a 2.x-only API;
# nixpkgs currently ships 1.29.0. New in 2.x: httpx2, mcp-types, pyjwt,
# python-multipart, typing-inspection, opentelemetry-api, jsonschema.
{
  lib,
  buildPythonPackage,
  fetchPypi,
  hatchling,
  anyio,
  httpx2,
  jsonschema,
  mcp-types,
  opentelemetry-api,
  pydantic,
  pyjwt,
  cryptography,
  python-multipart,
  sse-starlette,
  starlette,
  typing-extensions,
  typing-inspection,
  uv-dynamic-versioning,
  uvicorn,
}:

buildPythonPackage rec {
  pname = "mcp";
  version = "2.1.1";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-ULe6HrvhFwCOp73SiCNAQ+acILQD1oUdGWYebUMade8=";
  };

  build-system = [
    hatchling
    uv-dynamic-versioning
  ];

  # pyjwt[crypto] flattened to pyjwt + cryptography
  dependencies = [
    anyio
    cryptography
    httpx2
    jsonschema
    mcp-types
    opentelemetry-api
    pydantic
    pyjwt
    python-multipart
    sse-starlette
    starlette
    typing-extensions
    typing-inspection
    uvicorn
  ];

  pythonImportsCheck = [ ];
  doCheck = false;

  meta = {
    description = "Model Context Protocol SDK (2.x, required by scrapling)";
    homepage = "https://github.com/modelcontextprotocol/python-sdk";
    license = lib.licenses.mit;
  };
}
