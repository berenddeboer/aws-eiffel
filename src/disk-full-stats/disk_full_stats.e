note

	description:

		"For given mount point emit estimated time till full to AWS"

	library: "AWS Eiffel library"
	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2013, Berend de Boer"
	license: "MIT License (see LICENSE)"


class

	DISK_FULL_STATS


inherit

	CLOUDWATCH_TOOL
		redefine
			define_arguments,
			validate_arguments
		end


create

	make


feature {NONE} -- Initialisation

	make_no_rescue
			-- Read current disk free, and compare with last check.
		local
			mount_point: MOUNT_POINT
			now: EPX_TIME
			cloudwatch: AWS_CLOUDWATCH
			data_points: DS_LINKED_LIST [AWS_METRIC_DATUM]
			data_point: AWS_METRIC_DATUM
		do
			create now.make_from_now
			now.to_utc

			-- read previous bytes found, access time is last check time
			-- create mount_points.make
			create mount_point.make (parser.parameters.first, "xfs")
			--print ("free: " + mount_point.bytes_free.out + "%N")
			debug ("disk_full_stats")
				print ("written: " + mount_point.bytes_written.out + "%N")
				print ("seconds since last check: " + mount_point.seconds_since_last_check.out + "%N")
				print ("days to fill up: " + mount_point.days_to_fill_up.out + "%N")
			end

			create cloudwatch.make (access_key, secret_access_key, region.parameter)
			create data_points.make
			create data_point.make ("Days to fill up", mount_point.days_to_fill_up, "Count", now)
			data_point.add_dimension ("hostname", hostname)
			data_point.add_dimension ("path", mount_point.path)
			-- data_point.add_dimension ("volume", hostname + ":" + mount_point.path)
			data_points.put_last (data_point)
			cloudwatch.put_metric_data ("disk-fill-up-time", data_points)
			if cloudwatch.is_response_ok then
				if mount_point.seconds_since_last_check >= four_hours then
					mount_point.save_check
				end
			else
				stderr.put_line (cloudwatch.response_code.out + " " + cloudwatch.response_phrase)
				stderr.put_string (cloudwatch.response.as_string)
				-- exit_with_failure
			end
		end


feature -- Argument parsing

	description: STRING = "Time to disk full"

	define_arguments
		do
			precursor
			parser.set_parameters_description ("file-path")
		end

	validate_arguments
		do
			precursor
			if parser.parameters.is_empty then
				stderr.put_line ("Give mount point as argument.")
				parser.help_option.display_usage (parser)
			end
		end


feature {NONE} -- Implementation

	half_an_hour: INTEGER = 1800

	four_hours: INTEGER = 14400

end
