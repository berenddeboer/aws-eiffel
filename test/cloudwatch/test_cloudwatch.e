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

	AWS_ACCESS_KEY


feature -- Tests

	test_list_metrics
		local
			cloudwatch: AWS_CLOUDWATCH
		do
			create cloudwatch.make (region)
			cloudwatch.list_metrics ("aws-eiffel-test", "test-data-point")
			debug ("test")
				print (cloudwatch.response_code.out + " " + cloudwatch.response_phrase + "%N")
				if attached cloudwatch.response as response then
					print (response.as_string)
				end
			end
			assert ("Metrics listed", cloudwatch.is_response_ok)
		end

	test_put_metric_data
		local
			cloudwatch: AWS_CLOUDWATCH
			data_points: DS_LINKED_LIST [AWS_METRIC_DATUM]
			data_point: AWS_METRIC_DATUM
			now: EPX_TIME
		do
			create cloudwatch.make (region)

			-- create data_point.make ("test-data-point", 1, "Count", Void)
			-- create data_points.make
			-- data_points.put_last (data_point)
			-- cloudwatch.put_metric_data ("aws-eiffel-test", data_points)
			-- debug ("test")
			-- 	print (cloudwatch.response_code.out + " " + cloudwatch.response_phrase + "%N")
			-- 	print (cloudwatch.response.as_string)
			-- end
			-- assert ("Metric without time put", cloudwatch.is_response_ok)

			create now.make_from_now
			now.to_utc
			create data_points.make
			create data_point.make ("test data point", 0, "Count", now)
			data_points.put_last (data_point)
			cloudwatch.put_metric_data ("aws-eiffel-test", data_points)
			debug ("test")
				print (cloudwatch.response_code.out + " " + cloudwatch.response_phrase + "%N")
				if attached cloudwatch.response as response then
					print (response.as_string)
				end
			end
			assert ("Metric with time put", cloudwatch.is_response_ok)
		end


feature {NONE} -- Implementation

	region: STRING = "us-west-1"


end
