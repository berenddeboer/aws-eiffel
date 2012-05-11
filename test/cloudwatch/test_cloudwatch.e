note

	description:

		"Test AWS CloudWatch interface"

	library: "AWS Eiffel library"
	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2012, Berend de Boer"
	license: "MIT License (see LICENSE)"


deferred class

	TEST_CLOUDWATCH


inherit

	TS_TEST_CASE


feature -- Tests

	test_put_metric_data
		local
			key: EPX_ENV_VAR
			secret: EPX_ENV_VAR
			cloudwatch: AWS_CLOUDWATCH
			data_points: DS_LINKED_LIST [AWS_METRIC_DATUM]
			data_point: AWS_METRIC_DATUM
		do
			create key.make (once "S3_ACCESS_KEY_ID")
			create secret.make (once "S3_SECRET_ACCESS_KEY")
			create cloudwatch.make (key.value, secret.value)
			create data_point.make ("test-data-point", 1, "Count", Void)
			create data_points.make
			data_points.put_last (data_point)
			cloudwatch.put_metric_data ("aws-eiffel-test", data_points)
			debug ("test")
				print (cloudwatch.response_code.out + " " + cloudwatch.response_phrase + "%N")
				print (cloudwatch.response.as_string)
			end
			assert ("Metric put", cloudwatch.is_response_ok)
		end

	test_list_metrics
		local
			key: EPX_ENV_VAR
			secret: EPX_ENV_VAR
			cloudwatch: AWS_CLOUDWATCH
		do
			create key.make (once "S3_ACCESS_KEY_ID")
			create secret.make (once "S3_SECRET_ACCESS_KEY")
			create cloudwatch.make (key.value, secret.value)
			cloudwatch.list_metrics ("aws-eiffel-test", "test-data-point")
			debug ("test")
				print (cloudwatch.response_code.out + " " + cloudwatch.response_phrase + "%N")
				print (cloudwatch.response.as_string)
			end
			assert ("Metrics listed", cloudwatch.is_response_ok)
		end

end
