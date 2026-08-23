"""Tests container image build."""

from build.publish import main
from build.utils import (
    create_tag,
    get_valheim_build_id,
)
from click.testing import CliRunner, Result
from furl import furl
from requests import Response, get

from tests.constants import REGISTRY_TOKEN, REGISTRY_USERNAME


def test_image_build(
    registry: str,
    cli_runner: CliRunner,
) -> None:
    """Test building the container image with Podman and pushing it.

    :param registry:
    :param cli_runner:
    :return:
    """
    result: Result = cli_runner.invoke(
        main,
        env={
            "DOCKER_HUB_USERNAME": REGISTRY_USERNAME,
            "DOCKER_HUB_TOKEN": REGISTRY_TOKEN,
            "REGISTRY": registry,
            "PUBLISH_MANUALLY": "1",
        },
    )
    assert result.exit_code == 0, result.output

    catalog_url: furl = furl(f"http://{registry}")
    catalog_url.path /= "v2/_catalog"

    response: Response = get(catalog_url.url)

    assert response.status_code == 200
    assert response.json() == {"repositories": ["pfeiffermax/valheim-dedicated-server"]}

    tags_url: furl = furl(f"http://{registry}")
    tags_url.path /= "v2/pfeiffermax/valheim-dedicated-server/tags/list"

    response = get(tags_url.url)

    assert response.status_code == 200

    response_image_tags: list[str] = response.json()["tags"]

    tag: str = create_tag(get_valheim_build_id())

    assert tag in response_image_tags
    assert "latest" in response_image_tags
