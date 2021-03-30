{%
	let image_path = "/tmp/ucentral.upgrade";

	if (!args.uri) {
		result(2, "No firmware URL provided");
		return;
	}

	let download_cmdline = [ 'wget', '-O', image_path, args.uri ];
	let rc = system(download_cmdline);

	if (rc != 0) {
		result(2, "Download command %s exited with non-zero code %d", download_cmdline, rc);

		return;
	}

	let validation_result = ctx.call("system", "validate_firmware_image", { path: image_path });

	if (!validation_result) {
		result(2, "Validation call failed with status %s", ubus.error());

		return;
	}
	else if (!validation_result.valid) {
		result_json({
			"error": 2,
			"text": "Firmware image validation failed",
			"data": sprintf("Archive command %s exited with non-zero code %d", archive_cmdline, rc)
		});

		warn(sprintf("ucentral-upgrade: firmware file validation failed: %J\n", validation_result));

		return;
	}

	let archive_cmdline = [
		'tar', 'czf', '/tmp/sysupgrade.tgz',
		'/etc/config/ucentral'
	];

	let files = [ "cert.key", "cert.pem", "redirector.json", "dev-id" ];
	for (let f in files)
		if (fs.stat(f))
			push(archive_cmdline, f);

	if (args.keep_redirector) {
		let active_config = fs.readlink("/etc/ucentral/ucentral.active");

		if (active_config)
			push(archive_cmdline, '/etc/ucentral/ucentral.active', active_config);
		else
			result(2, "Unable to determine active configuration: %s", fs.error());
	}

	let rc = system(archive_cmdline);

	if (rc != 0) {
		result(2, "Archive command %s exited with non-zero code %d", archive_cmdline, rc);

		return;
	}

	let sysupgrade_cmdline = [
		'sysupgrade',
		...(args.keep_redirector ? [ '-f', '/tmp/sysupgrade.tgz' ] : []),
		image_path
	];

	warn("Upgrading firmware\n");

	system(['/etc/init.d/network', 'stop']);

	rc = system(sysupgrade_cmdline);

	if (rc != 0)
		result(2, "System upgrade command %s exited with non-zero code %d", sysupgrade_cmdline, rc);
%}
