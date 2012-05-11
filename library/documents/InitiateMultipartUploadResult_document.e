note

	description: "Generated class"

class

	INITIATEMULTIPARTUPLOADRESULT_DOCUMENT

inherit

	GEDXML_DOCUMENT
		rename
			document_element as InitiateMultipartUploadResult
		redefine
			InitiateMultipartUploadResult
		end

create

	make,
	make_from_file,
	make_from_stream,
	make_from_string

feature -- Status

	has_document_element: BOOLEAN
		do
			Result := template.InitiateMultipartUploadResult /= Void
		end

feature -- Access

	InitiateMultipartUploadResult: like template.InitiateMultipartUploadResult
		assign
			set_document_element

	template: INITIATEMULTIPARTUPLOADRESULT_TEMPLATE
		once
			create Result.make
		end

feature -- Change

	assign_document_element
		do
			InitiateMultipartUploadResult := template.InitiateMultipartUploadResult
		end

end
