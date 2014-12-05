Promise = require 'bluebird'

child_process = Promise.promisifyAll require 'child_process'

pg = require 'pg'

###################################################################################
# constants

DATABASE_NAME = 'mesa_integration_test'

DATABASE_URL = "postgres://localhost/#{DATABASE_NAME}"

dropCommand = "psql -c 'DROP DATABASE IF EXISTS #{DATABASE_NAME};'"
createCommand = "psql -c 'CREATE DATABASE #{DATABASE_NAME};'"

userTableSql = """
CREATE TABLE "user"(
  id SERIAL PRIMARY KEY,
  name text
);
"""

###################################################################################
# nice promise based wrapper around node-postgres

pgCallbackConnection = (cb) ->
  pg.connect DATABASE_URL, cb

pgPromiseConnection = ->
  new Promise (resolve, reject) ->
    pgCallbackConnection (err, connection, done) ->
      if err?
        return reject err
      resolve
        connection: connection
        done: done

pgQuery = (connection, sql, params) ->
  query = Promise.promisify(connection.query, connection)
  query sql, params

pgWrapInConnection = (block) ->
  pgPromiseConnection().then ({connection, done}) ->
    block(connection).finally ->
      done()

pgSingleQuery = (sql, params) ->
  pgWrapInConnection (connection) ->
    pgQuery connection, sql, params

pgDestroyPool = ->
  pool = pg.pools.all[JSON.stringify(DATABASE_URL)]
  console.log 'pgDestroyPool', 'pool?', pool?
  if pool?
    Promise.promisify(pool.destroyAllNow, pool)()
  else
    Promise.resolve()

###################################################################################
# mesa

mesa = require('../src/mesa').connection(pgCallbackConnection)

module.exports =

###################################################################################
# setup & teardown

  'setUp': (callback) ->
    console.log 'setUp', 'BEGIN'
    console.log 'setUp', 'drop database'
    child_process.execAsync(dropCommand)
      .then (stdout) ->
        # console.log stdout
        console.log 'setUp', 'create database'
        child_process.execAsync(createCommand)
      .then (stdout) ->
        # console.log stdout
        console.log 'setUp', 'create user table'
        pgSingleQuery userTableSql
      .then ->
        console.log 'setUp', 'END'
        callback()

  'tearDown': (callback) ->
    console.log 'tearDown', 'BEGIN'
    console.log 'tearDown', 'destroy pool'
    pgDestroyPool()
      .then ->
        console.log 'tearDown', 'drop database'
        child_process.execAsync(dropCommand)
      .then (stdout) ->
        console.log 'tearDown', 'END'
        callback()

###################################################################################
# integration tests

  'insert, read, update and delete a single user': (test) ->

    # exercising as much basic functionality as possible

    userTable = mesa
      .table('user')
      .allowedColumns(['name'])
      # .debug(console.log)

    userTable.insert(name: 'alice').bind({})
      .then (row) ->
        @insertedRow = row
        test.equal @insertedRow.name, 'alice'
        userTable.find()
      .then (rows) ->
        test.equal @insertedRow.id, rows[0].id
        userTable
          .where(id: @insertedRow.id)
          .returnFirst()
          .update(name: 'bob')
      .then (updatedRow) ->
        test.equal @insertedRow.id, updatedRow.id
        test.equal 'bob', updatedRow.name
        userTable
          .where(name: 'bob')
          .first()
      .then (bob) ->
        test.equal 'bob', bob.name
        userTable
          .where(id: @insertedRow.id)
          .returnFirst()
          .delete()
      .then (deletedRow) ->
        test.equal @insertedRow.id, deletedRow.id
        userTable.find()
      .then (rows) ->
        test.equal rows.length, 0
        test.done()
