note

	description:

		"Interface to Amazon CloudWatch"

	library: "Amazon CloudWatch library"
	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2012, Berend de Boer"
	license: "MIT License (see LICENSE)"


class

	AWS_CLOUDWATCH


inherit

	AWS_BASE

	UT_URL_ENCODING
		export
			{NONE} all
		end


create

	make


feature {NONE} -- Initialisation

	make (an_access_key_id, a_secret_access_key: READABLE_STRING_GENERAL)
		require
			access_key_has_correct_length: an_access_key_id /= Void and then an_access_key_id.count = 20
			secret_key_has_correct_length: a_secret_access_key /= Void and then a_secret_access_key.count = 40
		do
			make_secure (aws_cloudwatch_host_name)
			access_key_id := an_access_key_id
			create hasher.make (a_secret_access_key.out, create {EPX_SHA1_CALCULATION}.make)
		end


feature -- Access

	access_key_id: READABLE_STRING_GENERAL
			-- Access Key ID (a 20-character, alphanumeric sequence)

	aws_cloudwatch_host_name: STRING = "monitoring.amazonaws.com"
	--aws_cloudwatch_host_name: STRING = "monitoring.us-east-1.amazonaws.com"

	cloudwatch_version: STRING = "2010-08-01"

	cloudwatch_path: STRING = "/"


feature -- CloudWatch API

	list_metrics (a_name_space, a_metric_name: READABLE_STRING_GENERAL)
		local
			kv: EPX_KEY_VALUE
			data: DS_LINKED_LIST [EPX_KEY_VALUE]
			form: EPX_MIME_FORM
		do
			data := new_data ("ListMetrics", a_name_space)
			create kv.make ("MetricName", a_metric_name.out)
			data.put_last (kv)
			data.put_last (new_signature (http_method_POST, cloudwatch_path, data))
			create form.make_form_urlencoded (data.to_array)
			post (cloudwatch_path, form)
			read_response
		end

	put_metric_data (a_name_space: READABLE_STRING_GENERAL; a_data_points: DS_LINEAR [AWS_METRIC_DATUM])
		local
			i: INTEGER
			kv: EPX_KEY_VALUE
			data: DS_LINKED_LIST [EPX_KEY_VALUE]
			form: EPX_MIME_FORM
		do
			data := new_data ("PutMetricData", a_name_space)
			from
				i := 1
				a_data_points.start
			until
				a_data_points.after
			loop
				create kv.make ("MetricData.member." + i.out + ".MetricName", a_data_points.item_for_iteration.name.out)
				data.put_last (kv)
				create kv.make ("MetricData.member." + i.out + ".Unit", a_data_points.item_for_iteration.unit.out)
				data.put_last (kv)
				create kv.make ("MetricData.member." + i.out + ".Value", a_data_points.item_for_iteration.value.out)
				data.put_last (kv)
				create kv.make ("MetricData.member." + i.out + ".Timestamp", a_data_points.item_for_iteration.timestamp.as_iso_8601)
				data.put_last (kv)
				a_data_points.forth
			end
			data.put_last (new_signature (http_method_POST, cloudwatch_path, data))
			create form.make_form_urlencoded (data.to_array)
			post (cloudwatch_path + "?Action=PutMetricData", form)
			read_response
		end


feature {NONE} -- Request signing

	new_signature (a_verb, a_path: READABLE_STRING_GENERAL; a_data: DS_LINEAR [EPX_KEY_VALUE]): EPX_KEY_VALUE
		require
			a_verb_not_empty: a_verb /= Void and then not a_verb.is_empty
			a_path_not_empty: a_path /= Void and then not a_path.is_empty
			a_data_not_void: a_data /= Void
		do
			create Result.make ("Signature", signature (a_verb, a_path, a_data))
		end

	hasher: EPX_HMAC_CALCULATION

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

			Result := as_base64 (hasher.binary_checksum)
		ensure
			not_empty: Result /= Void and then not Result.is_empty
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
				Result.append_string (escape_string (l.item_for_iteration.value))
				l.forth
				if not l.after then
					Result.append_character ('&')
				end
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


feature {NONE} -- Implementation

	new_data (an_action, a_name_space: READABLE_STRING_GENERAL): DS_LINKED_LIST [EPX_KEY_VALUE]
		local
			kv: EPX_KEY_VALUE
			now: STDC_TIME
		do
			create Result.make
			create kv.make ("AWSAccessKeyId", access_key_id.out)
			Result.put_last (kv)
			create kv.make ("SignatureVersion", "2")
			Result.put_last (kv)
			create kv.make ("SignatureMethod", "HmacSHA1")
			Result.put_last (kv)
			create kv.make ("Action", an_action.out)
			Result.put_last (kv)
			create kv.make ("Version", cloudwatch_version)
			Result.put_last (kv)
			create kv.make ("Namespace", a_name_space.out)
			Result.put_last (kv)
			create now.make_from_now
			now.to_utc
			create kv.make ("Timestamp", now.as_iso_8601.out)
			Result.put_last (kv)
		ensure
			not_void: Result /= Void
		end

end
