mysql2json
==========

Database to JSON object conversion tool with support for PHP serialization.

### About

This command line tool will export the specified database to a "pretty print" JSON object. Auto-detection of PHP serialized strings will also be converted to a JSON object. This tool allows for simple line-by-line representation of a MySQL database and is perfect for viewing content in text based comparison tools.

#### Help
Type mysql2json --help

```
Exports a given database to a JSON file with PHP serialization conversion.
Usage: mysql2json [OPTION]... [DATABASE]

Example: 

  mysql2json -u root -p exampleDB123

or

 mysql2json --user=root exampleDB123

Connects to MySQL database on port 3306 with root credentials
and no password followed by dumping the database to a JSON file
of the same name containing all tables, creation definition and any
PHP serialized strings to child objects in 'pretty print' for
line-by-line analysis. The database name should be the last
argument parameter.

Startup:
  -?, --help           print this help
  -h, --host           host name or IP address (default: localhost)
  -l, --list           list databases & tables available for export
  -o, --output         output path & file (default is db name in current folder)
  -p, --password       password to connect with (default is none)
  -P, --port           the TCP/IP port number to connect on
  -t, --tables         a comma delimited list of tables (default empty for all)
  -u, --user           username to connect as (default: root)
  -q, --quiet          quiet (no output)
  -v, --version        output version number
  ```
  