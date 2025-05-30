"""Tests Docker image build."""

from click.testing import CliRunner, Result
from furl import furl
from python_on_whales import DockerClient
from requests import Response, get
from requests.auth import HTTPBasicAuth
from testcontainers.registry import DockerRegistryContainer

from build.publish import main
from build.utils import (
    create_tag,
    get_valheim_build_id,
)
from tests.constants import REGISTRY_PASSWORD, REGISTRY_USERNAME

BASIC_AUTH: HTTPBasicAuth = HTTPBasicAuth(REGISTRY_USERNAME, REGISTRY_PASSWORD)


def test_image_build(
    registry_container: DockerRegistryContainer,
    cli_runner: CliRunner,
    docker_client: DockerClient,
):
    """Test building the Docker image.

    :param registry_container:
    :param cli_runner:
    :param docker_client:
    :return:
    """
    result: Result = cli_runner.invoke(
        main,
        env={
            "DOCKER_HUB_USERNAME": REGISTRY_USERNAME,
            "DOCKER_HUB_PASSWORD": REGISTRY_PASSWORD,
            "REGISTRY": registry_container.get_registry(),
            "PUBLISH_MANUALLY": "1",
        },
    )
    assert result.exit_code == 0

    furl_item: furl = furl(f"http://{registry_container.get_registry()}")
    furl_item.path /= "v2/_catalog"

    # response: Response = get(furl_item.url, auth=BASIC_AUTH)
    response: Response = get(furl_item.url)

    assert response.status_code == 200
    assert response.json() == {"repositories": ["pfeiffermax/valheim-dedicated-server"]}

    furl_item: furl = furl(f"http://{registry_container.get_registry()}")
    furl_item.path /= "v2/pfeiffermax/valheim-dedicated-server/tags/list"

    # response: Response = get(furl_item.url, auth=BASIC_AUTH)
    response: Response = get(furl_item.url)

    assert response.status_code == 200

    response_image_tags: list[str] = response.json()["tags"]

    current_rust_server_build_id = get_valheim_build_id()
    tag = create_tag(current_rust_server_build_id)

    assert tag in response_image_tags
    assert "latest" in response_image_tags
