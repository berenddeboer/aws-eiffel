note

	description:

		"Base class for s3 based utilities"

	library: "S3 library"

	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2011, Berend de Boer"
	license: "MIT License (see LICENSE)"


deferred class

	S3_TOOL


inherit

	EPX_CURRENT_PROCESS


inherit {NONE}

	AWS_ACCESS_KEY

	AWS_REGION
		rename
			region as default_region
		end

	S3_VERBOSE_ROUTINES
		export
			{NONE} all
		end


feature {NONE} -- Initialize

	make
			-- Initialize and print exception if exception occurs.
		do
			make_no_rescue
		rescue
			if exceptions.is_developer_exception then
				if attached exceptions.developer_exception_name as name then
					fd_stderr.put_line (name)
				end
			else
				fd_stderr.put_string (once "Exception code: ")
				fd_stderr.put_line (exceptions.exception.out)
			end
			if exceptions.exception /= exceptions.developer_exception then
				if attached exceptions.exception_trace as exception_trace then
					fd_stderr.put_string (exception_trace)
				end
			end
			exit_with_failure
		end


	make_no_rescue
		deferred
		end


feature -- Access

	region: STRING

	region_option: AP_STRING_OPTION

	bucket: AP_STRING_OPTION

	verbose: AP_FLAG

	reduced_redundancy: AP_FLAG


feature -- Command-line parsing

	new_default_parser (a_description: STRING): AP_PARSER
			-- Parser with default options
		require
			description_not_empty: a_description /= Void and then not a_description.is_empty
		do
			create Result.make
			Result.set_application_description (a_description)
			Result.set_parameters_description (once "")
			create bucket.make ('b', "bucket")
			bucket.set_description ("Bucket name.")
			bucket.enable_mandatory
			Result.options.force_last (bucket)
			create region_option.make ('r', "region")
			region_option.set_description ("Region.")
			Result.options.force_last (region_option)
			create reduced_redundancy.make_with_long_form ("reduced-redundancy")
			reduced_redundancy.set_description ("Region.")
			Result.options.force_last (reduced_redundancy)
			create verbose.make ('v', "verbose")
			verbose.set_description ("Verbose output like progress.")
			Result.options.force_last (verbose)
		ensure
			not_void: Result /= Void
		end

	do_parse_arguments (a_parser: AP_PARSER)
			-- Parse arguments.
		require
			not_void: a_parser /= Void
			valid_options: a_parser.valid_options
		do
			a_parser.parse_arguments
			if region_option.occurrences > 0 and then attached region_option.parameter as l_region then
				region := l_region
			elseif not default_region.is_empty then
				region := default_region
			else
				fd_stderr.put_line ("Region not set. Please define it in ~/.aws/config or pass the --region parameter.")
				a_parser.help_option.display_usage (a_parser)
				-- silence compiler
				region := ""
			end
			if access_key_id.is_empty then
				fd_stderr.put_line ("Access key not set. Please define it in ~/.aws/config.")
				a_parser.help_option.display_usage (a_parser)
			end
			if secret_access_key.is_empty then
				fd_stderr.put_line ("Secret key not set. Please define it in ~/.aws/credentials.")
				a_parser.help_option.display_usage (a_parser)
			end
		ensure
			region_set: not region.is_empty
			access_key_set: not access_key_id.is_empty
			secret_access_key_set: not secret_access_key.is_empty
		end


end
