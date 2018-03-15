note

	description:

		"Make it easier to track many data points and publish them at once"

	library: "Amazon CloudWatch library"
	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2018, Berend de Boer"
	license: "MIT License (see LICENSE)"


class

	AWS_CLOUDWATCH_NAME_SPACE


inherit

	AWS_CLOUDWATCH_CHECKS


inherit {NONE}

	AWS_REGION

	AWS_METADATA
		rename
			region as metadata_region
		end



create

	make


feature {NONE} -- Initialisation

	make (a_name_space: READABLE_STRING_GENERAL)
		require
			valid_name_space: is_valid_name_space (a_name_space)
		do
			name_space := a_name_space
			create cloudwatch.make (region)
			create data_points.make
			create timestamp.make_from_now
			timestamp.to_utc
		end


feature -- Access

	cloudwatch: AWS_CLOUDWATCH

	name_space: READABLE_STRING_GENERAL

	data_points: DS_LINKED_LIST [AWS_METRIC_DATUM]
			-- Current data points

	timestamp: EPX_TIME
			-- Time to use for recording the statistics; updated when
			-- `wipe_out' is called


feature -- Status

	is_publish_failure: BOOLEAN
			-- Did last `publish' fail?


feature -- Commands

	add_data_point (a_name: READABLE_STRING_GENERAL; a_value: DOUBLE; a_unit: READABLE_STRING_GENERAL)
		require
			value_is_a_number: not a_value.is_nan
			value_is_not_negative_infinity: not a_value.is_negative_infinity
			value_is_not_positive_infinity: not a_value.is_positive_infinity
		local
			data_point: AWS_METRIC_DATUM
		do
			create data_point.make (a_name, a_value, a_unit, timestamp)
			data_point.add_dimension ("InstanceId", instance_id)
			data_points.put_last (data_point)
		end

	publish
			-- Publish all data points in `data_points' to AWS CloudWatch.
		require
			something_to_publish: not data_points.is_empty
		local
			ds: like data_points
		do
			-- We can sent only 20 data points at a time
			if data_points.count <= 20 then
				do_publish (data_points)
			else
				from
					create ds.make
					data_points.start
				until
					data_points.after
				loop
					ds.put_last (data_points.item_for_iteration)
					if ds.count = 20 then
						do_publish (ds)
						ds.wipe_out
					end
					ds.forth
				end
				if not ds.is_empty then
					do_publish (ds)
				end
			end
			is_publish_failure := not cloudwatch.is_response_ok
		end

	do_publish (a_data_points: like data_points)
		require
			no_overflow: a_data_points.count <= 20
		do
			cloudwatch.put_metric_data (name_space, a_data_points)
		end

	wipe_out
			-- Clear all data points.
			-- Also updates the timestamp
		do
			data_points.wipe_out
			timestamp.make_from_now
		end


end
