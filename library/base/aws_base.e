note

	description:

		"Base class for AWS services"

	library: "Eiffel AWS library"
	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2012, Berend de Boer"
	license: "MIT License (see LICENSE)"


deferred class

	AWS_BASE


inherit

	EPX_HTTP_11_CLIENT
		rename
			make as make_http_11_client
		end


inherit {NONE}

	UT_URL_ENCODING

	AWS_ACCESS_KEY


feature {NONE} -- Initialiation

	make_aws_base (a_server_name: READABLE_STRING_GENERAL)
		require
			access_key_has_correct_length: access_key_id /= Void and then access_key_id.count = 20
			secret_key_has_correct_length: secret_access_key /= Void and then secret_access_key.count = 40
		do
			make_http_11_client (a_server_name.out)
			-- make_secure (a_server_name)
			create hasher.make (secret_access_key.out, create {EPX_SHA1_CALCULATION}.make)
		end


feature -- Request signing

	hasher: EPX_HMAC_CALCULATION

	new_signature (a_verb, a_path: READABLE_STRING_GENERAL; a_data: DS_LINEAR [EPX_KEY_VALUE]): EPX_KEY_VALUE
			-- New AWS signature key/value pair
		require
			a_verb_not_empty: a_verb /= Void and then not a_verb.is_empty
			a_path_not_empty: a_path /= Void and then not a_path.is_empty
			a_data_not_void: a_data /= Void
		do
			create Result.make ("Signature", signature (a_verb, a_path, a_data))
		ensure
			not_void: Result /= Void
		end

	signature (a_verb, a_path: READABLE_STRING_GENERAL; a_data: DS_LINEAR [EPX_KEY_VALUE]): STRING
			-- Signature as per
			-- http://docs.amazonwebservices.com/AmazonCloudWatch/latest/DeveloperGuide/choosing_your_cloudwatch_interface.html#Using_Query_API
		require
			a_verb_not_empty: a_verb /= Void and then not a_verb.is_empty
			a_path_not_empty: a_path /= Void and then not a_path.is_empty
			a_data_not_void: a_data /= Void
		do
			if hasher.is_checksum_available then
				hasher.wipe_out
			end
			hasher.put_string (string_to_sign (a_verb, a_path, a_data))
			hasher.finalize

			if attached hasher.binary_checksum as bcs then
				Result := as_base64 (bcs)
			else
				-- silence void-safe compiler
				Result := ""
			end
		ensure
			not_empty: attached Result and then not Result.is_empty
		end

	string_to_sign (a_verb, a_path: READABLE_STRING_GENERAL; a_data: DS_LINEAR [EPX_KEY_VALUE]): STRING
			-- String to sign
			-- http://docs.amazonwebservices.com/AmazonCloudWatch/latest/DeveloperGuide/choosing_your_cloudwatch_interface.html#Using_Query_API
		require
			a_verb_not_empty: a_verb /= Void and then not a_verb.is_empty
			a_path_not_empty: a_path /= Void and then not a_path.is_empty
			a_data_not_void: a_data /= Void
		local
			l: DS_ARRAYED_LIST [EPX_KEY_VALUE]
			sorter: DS_BUBBLE_SORTER [EPX_KEY_VALUE]
		do
			-- Sort fields
			create sorter.make (create {EPX_KEY_VALUE_COMPARATOR})
			create l.make (a_data.count)
			from
				a_data.start
			until
				a_data.after
			loop
				l.put_last (a_data.item_for_iteration)
				a_data.forth
			end
			l.sort (sorter)

			create Result.make (256)
			Result.append_string (a_verb.out)
			Result.append_character ('%N')
			Result.append_string (server_name)
			Result.append_character ('%N')
			Result.append_string (a_path.out)
			Result.append_character ('%N')
			from
				l.start
			until
				l.after
			loop
				Result.append_string (l.item_for_iteration.key)
				Result.append_character ('=')
				Result.append_string (escape_custom (l.item_for_iteration.value, Default_unescaped, False))
				l.forth
				if not l.after then
					Result.append_character ('&')
				end
			end
			debug ("aws-print-string-to-sign")
				print ("--------------------------------------------------%N")
				print (Result)
				print ("%N")
				print ("--------------------------------------------------%N")
			end
		ensure
			not_empty: Result /= Void and then not Result.is_empty
		end

	as_base64 (buf: STDC_BUFFER): STRING
			-- Entire buffer in base64 encoding
		require
			buf_not_void: buf /= Void
		local
			output: KL_STRING_OUTPUT_STREAM
			base64: UT_BASE64_ENCODING_OUTPUT_STREAM
		do
			create Result.make (hasher.hash_output_length * 2)
			create output.make (Result)
			create base64.make (output, False, False)
			base64.put_string (buf.substring (0, buf.capacity-1))
			base64.close
		ensure
			not_empty: Result /= Void and then not Result.is_empty
		end


feature -- Methods

	version: STRING
			-- API version
		deferred
		end

	new_action (an_action: READABLE_STRING_GENERAL): DS_LINKED_LIST [EPX_KEY_VALUE]
			-- Key/value pairs for action `an_action'
		require
			an_action_not_empty: an_action /= Void and then not an_action.is_empty
		local
			kv: EPX_KEY_VALUE
			now: STDC_TIME
		do
			create Result.make
			create kv.make ("Action", an_action.out)
			Result.put_last (kv)
			create kv.make ("Version", version)
			Result.put_last (kv)
			create now.make_from_now
			now.to_utc
			create kv.make ("Timestamp", now.as_iso_8601.out)
			Result.put_last (kv)
			create kv.make ("SignatureVersion", "2")
			Result.put_last (kv)
			create kv.make ("SignatureMethod", "HmacSHA1")
			Result.put_last (kv)
			create kv.make ("AWSAccessKeyId", access_key_id.out)
			Result.put_last (kv)
			-- IAM role support
			if not iam_role_token.is_empty then
				create kv.make ("SecurityToken", iam_role_token)
				Result.put_last (kv)
			end
		ensure
			not_void: Result /= Void
		end


invariant

	hasher_not_void: hasher /= Void

end
