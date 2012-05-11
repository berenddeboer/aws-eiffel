note

	description: "Generated class"

class

	COMPLETEMULTIPARTUPLOADRESULT_DOCUMENT

inherit

	GEDXML_DOCUMENT
		rename
			document_element as CompleteMultipartUploadResult
		redefine
			CompleteMultipartUploadResult
		end

create

	make,
	make_from_file,
	make_from_stream,
	make_from_string

feature -- Status

	has_document_element: BOOLEAN
		do
			Result := template.CompleteMultipartUploadResult /= Void
		end

feature -- Access

	CompleteMultipartUploadResult: like template.CompleteMultipartUploadResult
		assign
			set_document_element

	template: COMPLETEMULTIPARTUPLOADRESULT_TEMPLATE
		once
			create Result.make
		end

feature -- Change

	assign_document_element
		do
			CompleteMultipartUploadResult := template.CompleteMultipartUploadResult
		end

end
