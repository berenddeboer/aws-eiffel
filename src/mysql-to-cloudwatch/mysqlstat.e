note

	description:

		"Short description of the class"

	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2017, Berend de Boer"
	license: "MIT License (see LICENSE)"


class

	MYSQLSTAT


inherit

	JRS


inherit {NONE}

	JRS_ODBC

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
			create mysql_status
			create slave_status
			create previous_values.make_default
			create new_values.make_default
			create name_space.make ("mysql")
		end


feature -- Access

	counters: DS_HASH_SET [READABLE_STRING_8]
			-- Counters which are reported as is
		once
			create Result.make_equal (4)
			-- The number of threads that are not sleeping.
			Result.put ("Threads_running")
			-- The number of currently open connections.
			Result.put ("Threads_connected")
			-- Result.put ("Qcache_queries_in_cache")
		end

	ignored_counters: DS_HASH_SET [READABLE_STRING_8]
			-- Counters which are queried, but only used in calculations.
		once
			create Result.make_equal (1)
			Result.put ("Max_used_connections")
		end

	diff_counters: DS_HASH_SET [READABLE_STRING_8]
			-- Counters for which we report the difference with the last value
		once
			create Result.make_equal (32)
			Result.force ("Aborted_connects")
			Result.force ("Connections")
			Result.force ("Bytes_received")
			Result.force ("Bytes_sent")
			Result.force ("Threads_created")
			Result.force ("Qcache_inserts")
			Result.force ("Qcache_hits")
			Result.force ("Qcache_lowmem_prunes")
			-- The number of statements executed by the server. This
			-- variable includes statements executed within stored
			-- programs, unlike the Questions variable. It does not count
			-- COM_PING or COM_STATISTICS commands.
			Result.force ("Queries")
			Result.force ("Com_select")
		end

	previous_values: DS_HASH_TABLE [INTEGER_64, READABLE_STRING_GENERAL]

	new_values: DS_HASH_TABLE [INTEGER_64, READABLE_STRING_GENERAL]


feature -- Commands

	publish
			-- Send latest data to AWS CloudWatch since last call to `publish'.
			-- When `publish' is called for the first time, it will only
			-- establish a base line and not send any data.
		local
			max_connections: INTEGER_64
			max_connections_used,
			connections_in_use: DOUBLE
			connections: INTEGER_64
			qcache_hits: INTEGER_64
			com_selects: INTEGER_64
			qcache_efficiency: DOUBLE
			threads_created: INTEGER_64
		do
			name_space.wipe_out
			previous_values := new_values
			create new_values.make (64)
			query ("mysqlcheck", "show global status where Variable_name in (" + field_parameters (counters) + ", " + field_parameters (ignored_counters) + ", " + field_parameters (diff_counters) + ")", Void, mysql_status).rows (agent publish_mysql_status)
			query ("mysqlcheck", "show slave status", Void, slave_status).rows (agent publish_mysql_slave_status)
			if new_values.count > 0 and previous_values.count > 0 then
				set_row ("mysqlcheck", "show global variables where Variable_name = 'max_connections'", Void, mysql_status)
				max_connections := mysql_status.value
				max_connections_used := (new_value  ("Max_used_connections") / max_connections) * 100
				connections := new_value  ("Connections") - previous_value ("Connections")
				connections_in_use := (connections / max_connections) * 100
				name_space.add_data_point ("Max used connections", max_connections_used, "Percent")
				name_space.add_data_point ("Connections in use", connections_in_use, "Percent")
				com_selects := new_value  ("Com_select") - previous_value ("Com_select")
				qcache_hits := new_value  ("Qcache_hits") - previous_value ("Qcache_hits")
				qcache_efficiency := (qcache_hits / (com_selects + qcache_hits)) * 100
				name_space.add_data_point ("Qcache efficiency", qcache_efficiency, "Percent")
				threads_created := new_value  ("Threads_created") - previous_value ("Threads_created")
				name_space.add_data_point ("Thread cache miss rate", (threads_created / connections) * 100, "Percent")
			end
			name_space.publish
			if name_space.is_publish_failure then
				stderr.put_line (name_space.cloudwatch.response_code.out + " " + name_space.cloudwatch.response_phrase)
				if attached name_space.cloudwatch.response as r then
					stderr.put_string (r.as_string)
				end
				--exit_with_failure
			end
		end


feature {NONE} -- Implementation

	field_parameters (c: DS_LINEAR [READABLE_STRING_8]): STRING
		do
			create Result.make_empty
			from
				c.start
			until
				c.after
			loop
				Result.append_character ('%'')
				Result.append_string (c.item_for_iteration)
				Result.append_character ('%'')
				c.forth
				if not c.after then
					Result.append_string (", ")
				end
			end
		end

	publish_mysql_status (a_row: like mysql_status; other: JRS_ROWS_ITERATOR_DATA): BOOLEAN
		local
			diff: INTEGER_64
		do
			if not ignored_counters.has (a_row.name) then
				if counters.has (a_row.name) then
					name_space.add_data_point (a_row.name, a_row.value, "Count")
				else
					previous_values.search (a_row.name)
					if previous_values.found then
						diff := a_row.value - previous_values.found_item
						name_space.add_data_point (a_row.name, diff, "Count")
					end
				end
			end
			new_values.put (a_row.value, a_row.name)
		end

	publish_mysql_slave_status (a_row: like slave_status; other: JRS_ROWS_ITERATOR_DATA): BOOLEAN
	local
			seconds_behind: STRING
			seconds: INTEGER_64
		do
			seconds_behind := a_row.fields.item ("Seconds_Behind_Master")
			if not seconds_behind.is_integer_64 then
				seconds :=seconds_behind.to_integer_64
			else
				seconds := 3600
			end
			name_space.add_data_point ("Seconds Behind Master", seconds, "Count")
		end

	mysql_status: TUPLE [
		name: STRING
		value: INTEGER_64
	]

	slave_status: TUPLE [
		fields: DS_HASH_TABLE [STRING, READABLE_STRING_GENERAL]
	]

	previous_value (a_name: READABLE_STRING_GENERAL): INTEGER_64
		do
			previous_values.search (a_name)
			if previous_values.found then
				Result := previous_values.found_item
			end
		end

	new_value (a_name: READABLE_STRING_GENERAL): INTEGER_64
		do
			new_values.search (a_name)
			if new_values.found then
				Result := new_values.found_item
			end
		end


feature {NONE} -- AWS Cloudwatch

	name_space: AWS_CLOUDWATCH_NAME_SPACE


end