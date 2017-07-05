note

	description:

		"This programs sends varnish stats from a given varnish instance to cloudwatch"

	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2017, Berend de Boer"
	license: "MIT License (see LICENSE)"


class

	VARNISH_TO_CLOUDWATCH


inherit

	EPX_SYSTEMD_DAEMON


create

	make


feature -- Access

	application_description: STRING = "Every minute sent varnish stats to AWS CloudWatch"


feature -- Eexecute

	execute
		local
			varnishstat: VARNISHSTAT
		do
			create varnishstat.make
			sd_notify_ready
			from
				varnishstat.publish
			until
				terminate_signal.should_stop
			loop
				sleep (60)
				if not terminate_signal.should_stop then
					varnishstat.publish
					watchdog_alive
				end
			end
			sd_notify_stopping
		end

end
