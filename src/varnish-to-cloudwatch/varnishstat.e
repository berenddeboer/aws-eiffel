note

	description:

		"Short description of the class"

	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2017, Berend de Boer"
	license: "MIT License (see LICENSE)"


class

	VARNISHSTAT


inherit

	JRS


inherit {NONE}

	AWS_ACCESS_KEY
		export
			{NONE} all
		end

	AWS_REGION

	AWS_METADATA
		rename
			region as metadata_region
		end


create

	make


feature {NONE} -- Initialisation

	make
		do
			-- TODO: support -n
			create varnish_record
			create previous_values.make_default
			create new_values.make_default
			create now.make_from_now
		end


feature -- Access

	counters: DS_HASH_SET [READABLE_STRING_8]
			-- Counters which are reported as is
		once
			create Result.make_equal (4)
			-- This value must always be 0 (or not even appear in your
			-- output). Having a threads_limited greater than 0 means
			-- that Varnish could not create new threads to serve
			-- requests.
			Result.put ("MAIN.threads_limited")
			-- Number of vcls loaded
			Result.put ("MAIN.n_vcl")
			-- Number of backends known. Includes stale vcls, so cleanup
			-- those and you have an accurate number of backends, which
			-- can either be healthy or sick.
			Result.put ("MAIN.n_backend")
			-- Number of threads in all pools.
			Result.put ("MAIN.threads")
		end

	diff_counters: DS_HASH_SET [READABLE_STRING_8]
			-- Counters for which we report the difference with the last value
		once
			create Result.make_equal (32)
			-- Number of objects that expired from cache because of old age.
			Result.force ("MAIN.n_expired")
			-- How many objects have been forcefully evicted from storage
			-- to make room for a new object.
			Result.force ("MAIN.n_lru_nuked")
			-- Count of incoming sessions successfully accepted
			Result.force ("MAIN.sess_conn")
			-- Number of times incoming session was queued waiting for a thread.
			Result.force ("MAIN.sess_queued")
			-- Number of times incoming session was dropped because the queue were too long already.
			Result.force ("MAIN.sess_dropped")
			-- The count of parseable client requests seen.
			Result.force ("MAIN.client_req")
			-- Count of cache hits.  A cache hit indicates that an object
			-- has been delivered to a client without fetching it from a
			-- backend server.
			Result.force ("MAIN.cache_hit")
			-- Count of misses A cache miss indicates the object was
			-- fetched from the backend before delivering it to the
			-- backend.
			Result.force ("MAIN.cache_miss")
			-- Number of times Varnish couldn't "ping" the backend (it
			-- didn't respond with a HTTP 200 response.
			Result.force ("MAIN.backend_unhealthy")
			-- Number of times Varnish couldn't connect to the backend.
			Result.force ("MAIN.backend_fail")
			-- Backend requests made
			Result.force ("MAIN.backend_req")
			-- Fetch EOF: beresp.body with EOF.
			Result.force ("MAIN.fetch_eof")
			--  Fetch bad T-E: beresp.body length/fetch could not be determined.
			Result.force ("MAIN.fetch_bad")
			-- Fetch failed (all causes): beresp fetch failed.
			Result.force ("MAIN.fetch_failed")
			-- Fetch no body: beresp.body empty
			Result.force ("MAIN.fetch_none")
			--  Fetch failed (no thread): beresp fetch failed, no thread available.
			Result.force ("MAIN.fetch_no_thread")
		end

	previous_values: DS_HASH_TABLE [like varnish_record, READABLE_STRING_GENERAL]

	new_values: DS_HASH_TABLE [like varnish_record, READABLE_STRING_GENERAL]


feature -- Commands

	publish
			-- Send latest data to AWS CloudWatch since last call to `publish'.
			-- When `publish' is called for the first time, it will only
			-- establish a base line and not send any data.
		local
			misses,
			hits: INTEGER_64
			hitrate: DOUBLE
		do
			previous_values := new_values
			create new_values.make (64)
			create now.make_from_now
			now.to_utc
			exec ("varnishstat -1 -t 0" + field_parameters (counters) + field_parameters (diff_counters)).as_tuples (varnish_record, ' ').each (agent investigate_varnish_field)
			if new_values.count > 0 and previous_values.count > 0 then
				misses := new_value  ("MAIN.cache_miss") - previous_value ("MAIN.cache_miss")
				hits := new_value  ("MAIN.cache_hit") - previous_value ("MAIN.cache_hit")
				hitrate := (hits / (hits + misses)) * 100
				publish_varnish_field ("hitrate", hitrate, "Percent")
			end
		end


feature {NONE} -- Implementation

	now: EPX_TIME
			-- Time whan varnishstat was last called

	field_parameters (c: DS_LINEAR [READABLE_STRING_8]): STRING
		do
			create Result.make_empty
			from
				c.start
			until
				c.after
			loop
				Result.append_string (" -f ")
				Result.append_string (c.item_for_iteration)
				c.forth
			end
		end

	varnish_record: TUPLE [
		field: detachable STRING
		value: INTEGER_64
		average: detachable STRING
		description: detachable STRING
	]

	investigate_varnish_field (l: JRS_TRANSFORMING_ITERATOR [READABLE_STRING_GENERAL, like varnish_record]): BOOLEAN
			-- Varnish only published increasing counters, so we need to
			-- publish the difference between the last value.
		local
			diff: INTEGER_64
		do
			if attached l.last_item as item and then attached item.field as name then
				if counters.has (name) then
					publish_varnish_field (name, item.value, "Count")
				else
					previous_values.search (name)
					if previous_values.found then
						diff := item.value - previous_values.found_item.value
						publish_varnish_field (name, diff, "Count")
					end
				end
				new_values.put (item, name)
			end
		end

	publish_varnish_field (name: STRING; a_value: DOUBLE; a_unit: STRING)
			-- Send a value to CloudWatch.
		local
			cloudwatch: AWS_CLOUDWATCH
			data_points: DS_LINKED_LIST [AWS_METRIC_DATUM]
			data_point: AWS_METRIC_DATUM
		do
			if a_value >= 0 then
				create cloudwatch.make (region)
				create data_points.make
				create data_point.make (name, a_value, a_unit, now)
				data_point.add_dimension ("InstanceId", instance_id)
				data_points.put_last (data_point)
				cloudwatch.put_metric_data ("varnish", data_points)
				if not cloudwatch.is_response_ok then
					if attached cloudwatch.response_phrase as rp then
						stderr.put_line (cloudwatch.response_code.out + " " + rp)
					end
					if attached cloudwatch.response as response then
						stderr.put_string (response.as_string)
					end
				end
			else
				-- Some sanity protection, this can happen if varnish
				-- gets restarted, so old values apply to previous instance.
				stderr.put_line ("Rejected " + name + " as value < 0: " + a_value.out)
			end
		end

	previous_value (a_name: READABLE_STRING_GENERAL): INTEGER_64
		do
			previous_values.search (a_name)
			if previous_values.found then
				Result := previous_values.found_item.value
			end
		end

	new_value (a_name: READABLE_STRING_GENERAL): INTEGER_64
		do
			new_values.search (a_name)
			if new_values.found then
				Result := new_values.found_item.value
			end
		end

end
