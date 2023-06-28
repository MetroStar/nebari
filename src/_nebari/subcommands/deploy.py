import pathlib

import typer

from _nebari.deploy import deploy_configuration

# from _nebari.render import render_template
from nebari.hookspecs import hookimpl


@hookimpl
def nebari_subcommand(cli: typer.Typer):
    @cli.command()
    def deploy(
        ctx: typer.Context,
        config_filename: pathlib.Path = typer.Option(
            ...,
            "--config",
            "-c",
            help="nebari configuration yaml file path",
        ),
        output_directory: pathlib.Path = typer.Option(
            "./",
            "-o",
            "--output",
            help="output directory",
        ),
        dns_provider: str = typer.Option(
            False,
            "--dns-provider",
            help="dns provider to use for registering domain name mapping",
        ),
        dns_auto_provision: bool = typer.Option(
            False,
            "--dns-auto-provision",
            help="Attempt to automatically provision DNS, currently only available for `cloudflare`",
        ),
        disable_prompt: bool = typer.Option(
            False,
            "--disable-prompt",
            help="Disable human intervention",
        ),
        disable_render: bool = typer.Option(
            False,
            "--disable-render",
            help="Disable auto-rendering in deploy stage",
        ),
        disable_checks: bool = typer.Option(
            False,
            "--disable-checks",
            help="Disable the checks performed after each stage",
        ),
        skip_remote_state_provision: bool = typer.Option(
            False,
            "--skip-remote-state-provision",
            help="Skip terraform state deployment which is often required in CI once the terraform remote state bootstrapping phase is complete",
        ),
    ):
        """
        Deploy the Nebari cluster from your [purple]nebari-config.yaml[/purple] file.
        """
        from nebari.plugins import nebari_plugin_manager

        stages = nebari_plugin_manager.ordered_stages
        config = nebari_plugin_manager.read_configuration(config_filename)

        if not disable_render:
            nebari_plugin_manager.render_stages(
                template_directory=output_directory, dry_run=False
            )

        deploy_configuration(
            config,
            stages,
            dns_provider=dns_provider,
            dns_auto_provision=dns_auto_provision,
            disable_prompt=disable_prompt,
            disable_checks=disable_checks,
            skip_remote_state_provision=skip_remote_state_provision,
        )
