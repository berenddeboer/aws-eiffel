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
			Result.put ("Max_used_connections")
			-- The number of threads that are not sleeping.
			Result.put ("Threads_running")
			-- The number of currently open connections.
			Result.put ("Threads_connected")
			-- Result.put ("Qcache_queries_in_cache")
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

			-- The number of misses for open tables cache lookups
			Result.force ("Table_open_cache_misses")
			-- The number of misses for open tables cache lookups
			Result.force ("Table_open_cache_hits")

			-- Locks
			-- The number of times that a request for a table lock could
			-- be granted immediately.
			Result.force ("Table_locks_immediate")
			-- The number of times that a request for a table lock could
			-- not be granted immediately and a wait was needed. If this
			-- is high and you have performance problems, you should
			-- first optimize your queries, and then either split your
			-- table or tables or use replication.
			Result.force ("Table_locks_waited")

			-- Internal in-memory temporary tables
			Result.force ("Created_tmp_tables")
			Result.force ("Created_tmp_files")
			Result.force ("Created_tmp_disk_tables")

			-- InnoDB
			Result.force ("Innodb_buffer_pool_wait_free")
			Result.force ("Innodb_log_waits")
		end

	ignored_counters: DS_HASH_SET [READABLE_STRING_8]
			-- Any counters in `counters' or `diff_counters' not sent to
			-- AWS CloudWatch, but only used for calculations.
		once
			create Result.make_equal (3)
			Result.put ("Max_used_connections")
			Result.put ("Table_open_cache_hits")
			Result.put ("Table_locks_immediate")
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
			thread_cache_miss_rate: DOUBLE
			table_open_cache_hits,
			table_open_cache_misses: INTEGER_64
			table_cache_hit_rate: DOUBLE
			tmp_tables,
			tmp_disk_tables: INTEGER_64
		do
			debug ("mysql_to_cloudwatch")
				print ("GATHERING%N")
			end
			name_space.wipe_out
			previous_values := new_values
			create new_values.make (64)
			query ("mysqlcheck", "show global status where Variable_name in (" + field_parameters (counters) + ", " + field_parameters (diff_counters) + ")", Void, mysql_status).rows (agent publish_mysql_status)
			query ("mysqlcheck", "show slave status", Void, slave_status).rows (agent publish_mysql_slave_status)

			-- Log calculated values
			if new_values.count > 0 and previous_values.count > 0 then
				set_row ("mysqlcheck", "show global variables where Variable_name = 'max_connections'", Void, mysql_status)
				max_connections := mysql_status.value
				max_connections_used := (new_value  ("Max_used_connections") / max_connections) * 100
				connections := new_value  ("Connections") - previous_value ("Connections")
				connections_in_use := (connections / max_connections) * 100
				name_space.add_data_point ("Max used connections", max_connections_used, "Percent")
				name_space.add_data_point ("Connections in use", connections_in_use, "Percent")

				-- Query cache statistics
				com_selects := new_value  ("Com_select") - previous_value ("Com_select")
				qcache_hits := new_value  ("Qcache_hits") - previous_value ("Qcache_hits")
				qcache_efficiency := (qcache_hits / (com_selects + qcache_hits)) * 100
				if qcache_efficiency >= 0 then
					name_space.add_data_point ("Qcache efficiency", qcache_efficiency, "Percent")
				end

				-- Thread cache statistics
				-- What percentage of connections required a new thread to
				-- be created.
				-- See also: https://serverfault.com/a/729353/100718
				if connections > 0 then
					threads_created := new_value  ("Threads_created") - previous_value ("Threads_created")
					thread_cache_miss_rate := (threads_created / connections) * 100
				else
					thread_cache_miss_rate := 0
				end
				name_space.add_data_point ("Thread cache miss rate", thread_cache_miss_rate, "Percent")

				-- Table cache statistics
				table_open_cache_hits := new_value  ("Table_open_cache_hits") - previous_value ("Table_open_cache_hits")
				table_open_cache_misses := new_value  ("Table_open_cache_misses") - previous_value ("Table_open_cache_misses")
				table_cache_hit_rate := (table_open_cache_hits / (table_open_cache_hits + table_open_cache_misses)) * 100
				name_space.add_data_point ("Table cache hit rate", table_cache_hit_rate, "Percent")

				-- Internal in-memory temporary tables
				tmp_tables := new_value  ("Created_tmp_tables") - previous_value ("Created_tmp_tables")
				tmp_disk_tables := new_value  ("Created_tmp_disk_tables") - previous_value ("Created_tmp_disk_tables")
				name_space.add_data_point ("Temporary tables created on disk rate", (tmp_disk_tables / tmp_tables) * 100, "Percent")
			end
			debug ("mysql_to_cloudwatch")
				print ("PUBLISHING%N")
			end
			name_space.publish
			debug ("mysql_to_cloudwatch")
				print ("DONE PUBLISHING%N")
			end
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
			if seconds_behind.is_integer_64 then
				seconds := seconds_behind.to_integer_64
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
