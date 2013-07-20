indexing

	description:

		"CloudWatch data point"

	library: "AWS library"
	author: "Berend de Boer <berend@pobox.com>"
	copyright: "Copyright (c) 2012, Berend de Boer"
	license: "MIT License (see LICENSE)"


class

	AWS_METRIC_DATUM


create

	make


feature {NONE} -- Initialisation

	make (a_name: READABLE_STRING_GENERAL; a_value: DOUBLE; a_unit: READABLE_STRING_GENERAL; a_timestamp: EPX_TIME)
			-- If timestamp not set, it is initialised to now
		require
			name_not_empty: is_valid_name (a_name)
			unit_valid: is_valid_unit (a_unit)
		do
			name := a_name
			value := a_value
			unit := a_unit
			if a_timestamp = Void then
				create timestamp.make_from_now
				timestamp.to_utc
			else
				timestamp := a_timestamp
			end
		end


feature -- Access

	name: READABLE_STRING_GENERAL
			-- The name of the metric

	unit: READABLE_STRING_GENERAL
			-- Valid Values: Seconds | Microseconds | Milliseconds |
			-- Bytes | Kilobytes | Megabytes | Gigabytes | Terabytes |
			-- Bits | Kilobits | Megabits | Gigabits | Terabits | Percent
			-- | Count | Bytes/Second | Kilobytes/Second |
			-- Megabytes/Second | Gigabytes/Second | Terabytes/Second |
			-- Bits/Second | Kilobits/Second | Megabits/Second |
			-- Gigabits/Second | Terabits/Second | Count/Second | None

	value: DOUBLE
			-- Although the Value parameter accepts numbers of type
			-- Double, Amazon CloudWatch truncates values with very large
			-- exponents. Values with base-10 exponents greater than 126
			-- (1 x 10^126) are truncated. Likewise, values with base-10
			-- exponents less than -130 (1 x 10^-130) are also truncated.

	timestamp: EPX_TIME
			-- The time stamp used for the datapoint;
			-- The time stamp used for the metric. If not specified, the
			-- default value is set to the time the metric data was
			-- received.

	dimensions: DS_HASH_TABLE [READABLE_STRING_GENERAL, READABLE_STRING_GENERAL]


feature -- Status

	is_valid_name (a_name: READABLE_STRING_GENERAL): BOOLEAN
		do
			Result := a_name /= Void and then not a_name.is_empty and then a_name.count <= 255
		end

	is_valid_unit (a_unit: READABLE_STRING_GENERAL): BOOLEAN
		do
			Result := a_unit /= Void and then not a_unit.is_empty
		end


feature -- Change

	add_dimension (a_name, a_value: READABLE_STRING_GENERAL)
			-- The Dimension data type further expands on the identity of
			-- a metric using a Name, Value pair.
		require
			a_name_not_empty: a_name /= Void and then not a_name.is_empty
			a_value_not_empty: a_value /= Void and then not a_value.is_empty
		do
			if dimensions = Void then
				create dimensions.make (2)
			end
			dimensions.force_last (a_value, a_name)
		ensure
			dimensions_not_void: dimensions /= Void
			dimension_added: dimensions.has (a_name)
		end

end
