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


create

	make


feature {NONE} -- Initialisation

	make (an_access_key_id, a_secret_access_key, a_region: READABLE_STRING_GENERAL)
		require
			access_key_has_correct_length: an_access_key_id /= Void and then an_access_key_id.count = 20
			secret_key_has_correct_length: a_secret_access_key /= Void and then a_secret_access_key.count = 40
			a_region_not_empty: a_region /= Void and then not a_region.is_empty
		do
			make_aws_base ("monitoring." + a_region.out + ".amazonaws.com", an_access_key_id, a_secret_access_key)
		end


feature -- Access

	--aws_cloudwatch_host_name: STRING = "monitoring.amazonaws.com"
	--aws_cloudwatch_host_name: STRING = "monitoring.us-east-1.amazonaws.com"

	version: STRING = "2010-08-01"
			-- API version

	cloudwatch_path: STRING = "/"
	--cloudwatch_path: STRING = "/doc/2010-08-01"


feature -- CloudWatch API

	list_metrics (a_name_space, a_metric_name: READABLE_STRING_GENERAL)
		require
			a_name_space_not_empty: a_name_space /= Void and then not a_name_space.is_empty
			a_metric_name_not_empty: a_metric_name /= Void and then not a_metric_name.is_empty
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
		require
			a_name_space_not_empty: a_name_space /= Void and then not a_name_space.is_empty
			a_data_points_not_void: a_data_points /= Void
		local
			i, j: INTEGER
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
				if attached a_data_points.item_for_iteration.dimensions as dimensions then
					from
						dimensions.start
						j := 1
					until
						dimensions.after
					loop
						create kv.make ("MetricData.member." + i.out + ".Dimensions.member." + j.out + ".Name", dimensions.key_for_iteration.out)
						data.put_last (kv)
						create kv.make ("MetricData.member." + i.out + ".Dimensions.member." + j.out + ".Value", dimensions.item_for_iteration.out)
						data.put_last (kv)
						dimensions.forth
						j := j + 1
					end
				end
				a_data_points.forth
				i := i + 1
			variant
				a_data_points.count - i + 1
			end
			data.put_last (new_signature (http_method_POST, cloudwatch_path, data))
			create form.make_form_urlencoded (data.to_array)
			post (cloudwatch_path + "?Action=PutMetricData", form)
			read_response
		end


feature {NONE} -- Implementation

	new_data (an_action, a_name_space: READABLE_STRING_GENERAL): DS_LINKED_LIST [EPX_KEY_VALUE]
		require
			an_action_not_empty: an_action /= Void and then not an_action.is_empty
			a_name_space_not_empty: a_name_space /= Void and then not a_name_space.is_empty
		local
			kv: EPX_KEY_VALUE
			now: STDC_TIME
		do
			Result := new_action (an_action)
			create kv.make ("Namespace", a_name_space.out)
			Result.put_last (kv)
		ensure
			not_void: Result /= Void
		end

end
