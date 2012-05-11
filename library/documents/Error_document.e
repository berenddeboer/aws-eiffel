note

	description: "Generated class"

class

	ERROR_DOCUMENT

inherit

	GEDXML_DOCUMENT
		rename
			document_element as Error
		redefine
			Error
		end

create

	make,
	make_from_file,
	make_from_stream,
	make_from_string

feature -- Status

	has_document_element: BOOLEAN
		do
			Result := template.Error /= Void
		end

feature -- Access

	Error: like template.Error
		assign
			set_document_element

	template: ERROR_TEMPLATE
		once
			create Result.make
		end

feature -- Change

	assign_document_element
		do
			Error := template.Error
		end

end
