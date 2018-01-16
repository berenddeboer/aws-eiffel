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


feature -- Execute

	execute
		local
			varnishstat: VARNISHSTAT
			start: EPX_TIME
			send: EPX_TIME
			seconds_to_sleep: INTEGER
		do
			create varnishstat.make
			sd_notify_ready
			create send.make_from_now
			from
				create start.make_from_now
				varnishstat.publish
			until
				terminate_signal.should_stop
			loop
				send.make_from_now
				seconds_to_sleep := interval - (send.value - start.value)
				if seconds_to_sleep >= 0 then
					sleep (seconds_to_sleep)
				else
					-- Negative, what's going on? Perhaps the system is overloaded? Rest a while...
					stderr.put_line ("Publish last data points took more than " + interval.out + " seconds. Sleeping for 120s now, perhaps system is overloaded?")
					sleep (120)
				end
				if not terminate_signal.should_stop then
					start.make_from_now
					varnishstat.publish
					watchdog_alive
				end
			end
			sd_notify_stopping
		end

	interval: INTEGER = 60

end
