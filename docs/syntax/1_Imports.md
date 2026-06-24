The syntax of imports is 
```
import [option] path.to.file

option := `akomaNtoso` | `formex`
```
where `path.to.file` is a sequence of identifiers. These identifiers are converted to a path `import_path := ${root_path}/path/to/file.${extension}` that identifies a file to be imported.

Depending on the option, the behavior of `import` behaves differently:
* If no option is specified, then `extension` is set to `.lex` and the content of the file at `import_path` is loaded into the context.
* If an option is specified, then `extension` is set to `.xml` and the content of the AkomaNtoso or Formex file is loaded into the context. AkomaNtoso and Formex are standard XML formats for machine-readable legal documents. When importing such files, the text of the law is imported (as comments) to the corresponding parts of the legal formalization by the Lex compiler. The Lex documentation files of the formalization then show both the formalization and the original legal text imported from the XML files.
  
