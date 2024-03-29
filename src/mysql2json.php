<?php
/**
 * MySQL2JSON Class and command line tool.
 */

// Resolve autoloader
foreach ([__DIR__ . '/../../../autoload.php', __DIR__ . '/../vendor/autoload.php'] as $file) {
  if (file_exists($file)) {
      require $file;
      break;
  }
}
use Steveorevo\GString as GString;

class __PHP_stdClass {
  public $__PHP_stdClass = true;
}

class MySQL2JSON {
  public $version = "2.1.3"; // TODO: obtain via composer
  public $climate = NULL;
  public $dbNames = [];
  public $tables = [];
  public $db;

  /**
   * Create our MySQL2JSON object
   */
  function __construct() {
 
  }

  /**
   * Process the command line interface arguments
   */
  function cli() {
    $composer = json_decode(file_get_contents(__DIR__ . "/../composer.json"));
    $this->climate = new League\CLImate\CLImate;
    $this->climate->description( $composer->description . "\nVersion " . $this->version);
    $this->climate->arguments->add([
      'help' => [
        'prefix'       => '?',
        'longPrefix'   => 'help',
        'description'  => 'print this help',
        'noValue'      => true,
      ],
      'host' => [
        'prefix'       => 'h',
        'longPrefix'   => 'hose',
        'description'  => 'host name or IP address (default: localhost)',
        'defaultValue' => 'localhost',
      ],
      'list' => [
        'prefix'      => 'l',
        'longPrefix'  => 'list',
        'description' => 'list databases & tables available for export',
        'noValue'     => true,
      ],
      'exclude' => [
        'prefix'      => 'x',
        'longPrefix'  => 'exclude',
        'description' => 'excludes rows with _transient_ in option_name column (WordPress)',
        'noValue'     => true,
      ],
      'output' => [
        'prefix'       => 'o',
        'longPrefix'   => 'output',
        'description'  => 'path & file (default is db name in current folder)',
        'defaultValue' => '',
      ],
      'password' => [
        'prefix'       => 'p',
        'longPrefix'   => 'password',
        'description'  => 'password to connect with (default is none)',
        'defaultValue' => '',
      ],
      'port' => [
        'prefix'      => 'P',
        'longPrefix'  => 'port',
        'description' => 'the TCP/IP port number to connect to',
        'castTo'      => 'int',
      ],
      'tables' => [
        'prefix'       => 't',
        'longPrefix'   => 'tables',
        'description'  => 'a comma delimited list of tables (default empty for all)',
        'defaultValue' => '',
      ],
      'user' => [
        'prefix'       => 'u',
        'longPrefix'   => 'user',
        'description'  => 'username to connect as (default: root)',
        'defaultValue' => 'root',
      ],
      'quiet' => [
        'prefix'       => 'q',
        'longPrefix'   => 'quiet',
        'description'  => 'quiet (no output)',
        'noValue'      => true
      ],
      'version' => [
        'prefix'       => 'v',
        'longPrefix'   => 'version',
        'description'  => 'output version number',
        'noValue'      => true,
      ],
      'database' => [
        'description'  => 'the database to export'
      ]
    ]);
    $this->climate->arguments->parse();
    if (! $this->climate->arguments->defined("help")) {
      $this->showVersion();
      $this->getDBNames();
      $this->doListing();
      $this->buildJSON();  
    }
    $this->climate->usage();
  }

  /**
   * Create a JSON representation of the given database and tables
   */
  function buildJSON() {
    $database = $this->climate->arguments->get('database');
    if (FALSE == in_array($database, $this->dbNames)) {
      if ($database == NULL) {
        echo "Missing database name.\nType 'mysql2json --help' for more options.\n";
      }else{
        echo "Unknown database: $database\n";
      }
      exit();
    }

    // Define the creation for databases and tables
    $this->getTables();
    $this->connectToDB($database);
    $objDB = new stdClass();
    $objDB->name = $database;
    $r = $this->db->query("SHOW CREATE DATABASE $database;");
    if ($r->num_rows > 0) {
      $row = $r->fetch_assoc();
      $objDB->create = $row["Create Database"];
    }
    $objDB->tables = [];
    foreach($this->tables as $name) {
      $r = $this->db->query("SHOW CREATE TABLE $name;");
      if ($r->num_rows > 0) {
        $row = $r->fetch_assoc();
        $table = new stdClass();
        $table->name = $name;

        // Strict mode compatibility 
        $sql = $row["Create Table"];
        $sql = str_replace("NOT NULL DEFAULT '0000-00-00 00:00:00'","NOT NULL DEFAULT '1000-01-01 00:00:00'", $sql);
        $table->create = $sql;
        $table->columns = [];
        $table->data = [];
        array_push($objDB->tables, $table);
      }
    }

    // Get column details for the given tables
    $mapString = ["char","varchar","tinytext","text","mediumtext","longtext","binary",
                  "varbinary","date","datetime","timestamp","time","year"];
    $mapNumber = ["bit","tinyint","smallint","mediumint","int","integer","bigint",
                  "decimal","dec","fixed","float","double","real"];
    $mapBoolean = ["bool", "boolean"];
    for ($i = 0; $i < count($objDB->tables); $i++) {
      $name = $objDB->tables[$i]->name;
      $r = $this->db->query("SHOW COLUMNS FROM $name;");
      if ($r->num_rows > 0) {
        while($row = $r->fetch_assoc()) {
          $column = new stdClass();
          $column->name = $row["Field"];
          $type = new GString($row["Type"]);
          $type = $type->getLeftMost("(")->__toString();
          $column->mysql_type = $type;
          if (FALSE !== in_array($type, $mapString)) {
            $type = "string";
          }else{
            if (FALSE !== in_array($type, $mapNumber)) {
              $type = "number";
            }else{
              if (FALSE !== in_array($type, $mapBoolean)) {
                $type = "boolean";
              }else{
                $type = NULL;
              }
            }
          }
          $column->json_type = $type;
          array_push($objDB->tables[$i]->columns, $column);
        }
      }
    }

    // Dump data for the given tables
    for ($i = 0; $i < count($objDB->tables); $i++) {
      $name = $objDB->tables[$i]->name;
      $columns = &$objDB->tables[$i]->columns;
      $r = $this->db->query("SELECT * FROM $name;");
      if ($r->num_rows > 0) {
        while($row = $r->fetch_assoc()) {
          
          // Check for exclude transients flag
          $skip = false;
          if ($this->climate->arguments->defined('exclude')) {
            if (array_key_exists('option_name', $row)) {
              if (false !== strpos($row['option_name'], '_transient_')) {
                $skip = true;
              }
            }
          }
          
          // Skip transients
          if (false == $skip) {

            // Check serialized data, update column data-type to object
            foreach($columns as &$col) {
              if ($this->is_serialized($row[$col->name])) {
                $col->json_type = 'object';
                $row[$col->name] = (object) unserialize($this->fix_serialized($row[$col->name]));
              }
            }
            array_push($objDB->tables[$i]->data, $row);
          }
        }
      }
      $r->free_result();
      if (! $this->climate->arguments->defined('quiet')) {
        echo "Exported table: " . $name . "\n";
      }
    }
    $this->db->close();
    $output = $this->climate->arguments->get('output');
    if ('' == $output) {
      $output = getcwd() . "/" . $database . ".json";
    }
    file_put_contents($output, json_encode($objDB, JSON_PRETTY_PRINT));
    if (! $this->climate->arguments->defined('quiet')) {
      echo "File export complete: $output\n";
    }
    exit();
  }

/**
 * Takes serialized PHP and converts objects that would otherwise become
 * __PHP_Incomplete_Class definitions and converts them to a stdClass 
 * object; allowing access to private and public property data.
 *
 * @param  string $data serialized PHP data
 * @return string data converted to stdClass with all properties
 */
  function fix_serialized($data) {

    // Convert existing 'stdClass' to '__PHP_stdClass' to distinguish it from arrays
    $data = str_replace('O:8:"stdClass"', 'O:14:"__PHP_stdClass"', $data);

    // Sense classes that have serialize implmented
    if (strpos($data, 'C:') !== false) {

      $tmp = new GString($data);
      $tmp = $tmp->delLeftMost('C:');
      $v = $tmp->getLeftMost(":")->__toString();
      if (is_numeric($v)) {

        // Extract the class name
        $tmp = $tmp->delLeftMost(":");
        $cname = $tmp->getLeftMost(":")->__toString();
        $tmp = $tmp->delLeftMost(":");

        // Extract the class data
        $tmp = $tmp->delLeftMost(":{");
        if (substr($tmp->__toString(), -1) == "}") {
          $cdata = substr($tmp->__toString(), 0, -1);

          $obj = new stdClass();
          $obj->__PHP_impSerialized = $cname;
          $obj->data = unserialize($this->fix_serialized($cdata));
          $data = serialize($obj);
        }
      }
    }

    // Make __PHP_Incomplete_Class private and protected properties public (replace null*null, and nullCLASSNAMEnull)
    $data = preg_replace_callback( 
        '/:\d+:"\0.*?\0([^"]+)"/',

        // Recalculate new key-length
        function($matches) {
          $prop = '';
          if (false !== strpos($matches[0], ":\"\0*")){
              $prop = '*|';
          }elseif (false !== strpos($matches[0], ":\"\0")){
              $prop = 'A|';
          }
          $prop .= $matches[1];
          return ":" . strlen( $prop ) . ":\"" . $prop . "\"";
        },
        $data
    );
    
    // Convert object references to '__PHP_reference' to prevent recursion errors
    if (strpos($data, '";r:') !== false) {
      
      $lines = explode('";r:', $data);
      for($i=0; $i < (count($lines)-1); $i++) {
        $line = $lines[$i]; 
        $line = new GString($line);
        $before = $line->delRightMost('s:')->__toString() . 's:';

        // Recalculate new key-length
        $n = $line->getRightMost('s:')->getLeftMost(':')->__toString();
        $n = intval($n) + 15; 
        $after = ':' . $line->getRightMost('s:')->delLeftMost(':')->__toString();
        $lines[$i] = utf8_encode($before . $n . $after);
      }
      $data = implode('__PHP_reference";i:', $lines);
    }

    // Return the corrected serialized data
    return $data;
  }

  /**
   * List available databases or tables for a given database
   */
  function doListing() {
    if (! $this->climate->arguments->defined('list')) return;
    $database = $this->climate->arguments->get('database');
    if (FALSE == $database) {
      echo "Databases:\n";
      foreach($this->dbNames as $name) {
        echo "   $name\n";
      } 
    }else{
      if (in_array($database, $this->dbNames)) {
        $this->getTables();
        echo "Tables in database $database:\n";
        foreach($this->tables as $name) {
          echo "   $name\n";
        }
      }else{
        echo "Unknown database: $database\n";
      }
    }
    exit();
  }

  /**
   * Show the version number
   */
  function showVersion() {
    if (! $this->climate->arguments->defined('version')) return;
    echo "MySQL2JSON version " . $this->version . "\n";
    echo "Copyright ©2018 Stephen J. Carnam\n";
    exit();
  }

  /**
   * Gather the list of tables in the given database
   */
  function getTables() {
    $database = $this->climate->arguments->get('database');
    $this->connectToDB($database);
    $r = $this->db->query('SHOW TABLES;');
    if ($r->num_rows > 0) {
      while($row = $r->fetch_assoc()) {
        
        // Limit to implicit tables argument if present
        $name = $row["Tables_in_$database"];
        if ($this->climate->arguments->defined('tables')) {
          $t = ',' . $this->climate->arguments->get('tables') . ',';
          if (FALSE !== strpos($t, "," . $name . ",")) {
            array_push($this->tables, $name);
          }
        }else{
          array_push($this->tables, $name);
        }
      }
    }
    $this->db->close();
  }

  /**
   * Gather a list of available databases
   */
  function getDBNames() {
    $this->connectToDB();
    $r = $this->db->query('SHOW DATABASES;');
    if ($r->num_rows > 0) {
      while($row = $r->fetch_assoc()) {
          array_push($this->dbNames, $row["Database"]);
      }
    }
    $this->db->close();
  }

  /**
   * Connect to the mysql database with the given credentials
   * string - the name of the database to connect to, default is mysql
   */
  function connectToDB($database = "mysql") {
    $host = $this->climate->arguments->get('host');
    if ($host == 'localhost') {
      $host = '127.0.0.1';
    }
    $user = $this->climate->arguments->get('user');
    $password = $this->climate->arguments->get('password');
    $this->db = new mysqli($host, $user, $password, $database);

    if ($this->db->connect_error) {
      die('Connection failed: ' . $this->db->connect_error);
    }
  }

  /**
   * Checks to see if the given data is PHP serialized data in a string.
   * 
   * @param (string) - the data to analyze.
   * @return (boolean) true if serialized or false if not.
   */
  function is_serialized($str) {
    $data = @unserialize($str);
    if ($str === 'b:0;' || $data !== false) {
        return true;
    } else {
        return false;
    }
  }
}

// From command line, create instance & do cli arguments
if ( PHP_SAPI === 'cli' ) {
  $myCmd = new MySQL2JSON();
  $name = new GString(__FILE__);
  $argv[0] = $name->getRightMost("/")->delRightMost(".");
  $myCmd->cli();
}
