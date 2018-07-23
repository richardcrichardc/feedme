package main


import (
  "github.com/jmoiron/sqlx"
  _ "github.com/lib/pq"
  "strings"
  "reflect"
  "log"
  "fmt"
  "strconv"
  "database/sql"
)

var db *sqlx.DB

func initDB() {
  db = sqlx.MustOpen("postgres", "dbname=feedme sslmode=disable")

  tx := db.MustBegin()

  tx.MustExec(
    `CREATE TABLE IF NOT EXISTS kv (
      k text PRIMARY KEY,
      v text
    )` )

  initialSchemaVersion := kvGetInt(tx, "schemaVersion", 0)

  schema := []string {
    `CREATE TABLE restaurants (
      id serial PRIMARY KEY,
      slug text NOT NULL,
      name text,
      address1 text,
      address2 text,
      town text,
      phone text,
      mapLocation text,
      mapZoom text,
      about text,
      nextOrderId int NOT NULL DEFAULT 1
    )`,
    `CREATE TABLE menus (
      id SERIAL PRIMARY KEY,
      restaurantId int REFERENCES restaurants(id),
      items text NOT NULL
    )`,
    `CREATE TABLE orders (
      restaurantId int,
      number int,
      created timestamp NOT NULL,
      name text NOT NULL,
      phone text NOT NULL,
      menu_id int NOT NULL,
      items text NOT NULL,
      subtotal numeric(11,2) NOT NULL,
      gst numeric(11,2) NOT NULL,
      PRIMARY KEY (restaurantId, number)
     )`,
   }

  for i := initialSchemaVersion; i < len(schema); i ++ {
    stmt := schema[i]
    log.Printf("DB migration %d:\n%s", i, stmt)
    tx.MustExec(stmt)
  }

  kvSetInt(tx, "schemaVersion", len(schema))
  checkError(tx.Commit())

}

func kvGet(tx *sqlx.Tx, key string, defaultValue string) string {
  var value string
  err := tx.Get(&value, "SELECT v FROM kv WHERE k=$1", key)

  if err == sql.ErrNoRows {
    return defaultValue
  }

  checkError(err)
  return value
}

func kvSet(tx *sqlx.Tx, key, value string) {
  tx.MustExec("INSERT INTO kv(k, v) VALUES($1, $2) ON CONFLICT(k) DO UPDATE SET v=$2 WHERE kv.k=$1", key, value)
}

func kvGetInt(tx *sqlx.Tx, key string, defaultValue int) int {
  var value string
  err := tx.Get(&value, "SELECT v FROM kv WHERE k=$1", key)

  if err == sql.ErrNoRows {
    return defaultValue
  }

  checkError(err)

  i, err := strconv.Atoi(value)
  checkError(err)
  return i
}

func kvSetInt(tx *sqlx.Tx, key string, value int) {
  kvSet(tx, key, strconv.Itoa(value))
}

func dbFetch(table, keyCol string, key interface{}, cols []string, dest interface{}) error {
  q := "SELECT " + strings.Join(cols, ", ") + " FROM " + table + " WHERE " + keyCol + " = $1"
  return db.Get(dest, q, key)
}

func dbFetchAll(table, keyCol string, key interface{}, dest interface{}) error {
  q := "SELECT * FROM " + table + " WHERE " + keyCol + " = $1"
  return db.Get(dest, q, key)
}

func dbInsert(table string, cols []string, src interface{}) error {
  const query = "INSERT INTO %s(%s) VALUES(%s)"

  var binds []string
  var args []interface{}

  for _, col := range cols {
    field := reflect.Indirect(reflect.ValueOf(src)).FieldByName(col)

    if !field.IsValid() {
      log.Panicf("dbInsert: src missing field '%s'", col)
    }

    binds = append(binds, "?")
    args = append(args, field.Interface())
  }

  colsStr := strings.Join(cols, ",")
  bindsStr := strings.Join(binds, ",")

  q := db.Rebind(fmt.Sprintf(query, table, colsStr, bindsStr))
  //log.Println(q)
  //log.Printf("%#v", args)

  _, err := db.Exec(q, args...)
  return err
}

func dbUpdate(table string, id int, cols []string, src interface{}) error {
  const query = "UPDATE %s SET %s WHERE id=?"

  var binds []string
  var args []interface{}

  for _, col := range cols {
    field := reflect.Indirect(reflect.ValueOf(src)).FieldByName(col)

    if !field.IsValid() {
      log.Panicf("dbUpdate: src missing field '%s'", col)
    }

    binds = append(binds, col+"=?")
    args = append(args, field.Interface())
  }

  bindsStr := strings.Join(binds, ",")
  args = append(args, id)

  q := db.Rebind(fmt.Sprintf(query, table, bindsStr))
  //log.Println(q)
  //log.Printf("%#v", args)

  _, err := db.Exec(q, args...)
  return err
}

func dbUpsert(table string, id int, cols []string, src interface{}) error {
  if id == 0 {
    return dbInsert(table, cols, src)
  } else {
    return dbUpdate(table, id, cols, src)
  }
}

func dbRealUpsert(table, keyCol string, key interface{}, cols []string, src interface{}) error {
  var insertArgs, updateArgs, args []interface{}
  var insertBinds, updateBinds []string

  // loops through cols to build ararys of binds and args
  for _, col := range cols {
    field := reflect.Indirect(reflect.ValueOf(src)).FieldByName(col)

    if !field.IsValid() {
      log.Panicf("dbUpsert: src missing field '%s'", col)
    }

    insertBinds = append(insertBinds, "?")
    updateBinds = append(updateBinds, col+"=?")

    arg := field.Interface()
    insertArgs = append(insertArgs, arg)
    updateArgs = append(updateArgs, arg)
  }

  // add primary key to insert
  insertBinds = append(insertBinds, "?")
  insertArgs = append(insertArgs, key)

  // join binds with ,
  colsStr := strings.Join(cols, ",") + ",id"
  insertBindsStr := strings.Join(insertBinds, ",")
  updateBindsStr := strings.Join(updateBinds, ",")

  // join args together
  args = append(args, insertArgs...)
  args = append(args, updateArgs...)
  args = append(args, key)

  const query = "INSERT INTO %s(%s) VALUES(%s) ON CONFLICT DO UPDATE %s SET %s WHERE id=?"
  q := fmt.Sprintf(query, table, colsStr, insertBindsStr, table, updateBindsStr)
  q = db.Rebind(q)
  log.Println(q)
  log.Printf("%#v", args)

  _, err := db.Exec(q, args...)
  return err
}
