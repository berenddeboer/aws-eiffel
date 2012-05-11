note

	description:

		"Base class for s3 based utilities"

	library: "S3 library"

	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2011, Berend de Boer"
	license: "MIT License (see LICENSE)"
	date: "$Date$"
	revision: "$Revision$"


deferred class

	S3_TOOL


inherit

	S3_ACCESS_KEY

	S3_VERBOSE_ROUTINES
		export
			{NONE} all
		end

	EPX_CURRENT_PROCESS


feature {NONE} -- Initialize

	make
			-- Initialize and print exception if exception occurs.
		do
			make_no_rescue
		rescue
			if exceptions.is_developer_exception then
				fd_stderr.put_line (exceptions.developer_exception_name)
			else
				fd_stderr.put_string (once "Exception code: ")
				fd_stderr.put_line (exceptions.exception.out)
			end
			exit_with_failure
		end


	make_no_rescue
		deferred
		end


feature -- Access

	region: AP_STRING_OPTION

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
			create region.make ('r', "region")
			region.set_description ("Region.")
			Result.options.force_last (region)
			create reduced_redundancy.make ('d', "reduced-redundancy")
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
		do
			a_parser.parse_arguments
			if access_key_id.is_empty then
				fd_stderr.put_line ("Environment variable S3_ACCESS_KEY_ID not set. It should contain your Amazon access key.")
				a_parser.help_option.display_usage (a_parser)
			end
			if secret_access_key.is_empty then
				fd_stderr.put_line ("Environment variable S3_SECRET_ACCESS_KEY not set. It should contain your Amazon secret access key.")
				a_parser.help_option.display_usage (a_parser)
			end
		end


end
