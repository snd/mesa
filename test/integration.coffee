Promise = require 'bluebird'

child_process = Promise.promisifyAll require 'child_process'

fs = Promise.promisifyAll require 'fs'
path = require 'path'

pg = require 'pg'

###################################################################################
# constants

DATABASE_NAME = 'mesa_integration_test'
DATABASE_URL = "postgres://localhost/#{DATABASE_NAME}"

dropDatabaseCommand = "psql -c 'DROP DATABASE IF EXISTS #{DATABASE_NAME};'"
createDatabaseCommand = "psql -c 'CREATE DATABASE #{DATABASE_NAME};'"

###################################################################################
# mesa

mesa = require('../src/mesa')
  .setConnection(
    (cb) -> pg.connect DATABASE_URL, cb
  )
  .debug (event) ->
    delete event.connection
    console.log event

###################################################################################
# helpers

pgDestroyPool = (config) ->
  poolKey = JSON.stringify(config)
  console.log 'pgDestroyPool'
  console.log 'Object.keys(pg.pools.all)', Object.keys(pg.pools.all)
  console.log 'poolKey', poolKey
  pool = pg.pools.all[poolKey]
  console.log 'pool?', pool?
  if pool?
    new Promise (resolve, reject) ->
      pool.drain ->
        # https://github.com/coopernurse/node-pool#step-3---drain-pool-during-shutdown-optional
        pool.destroyAllNow ->
          delete pg.pools.all[poolKey]
          resolve()
  else
    Promise.resolve()

###################################################################################
# setup & teardown

module.exports =

  'setUp': (done) ->
    console.log 'setUp', 'BEGIN'
    console.log 'setUp', 'drop database'
    resetDatabase = child_process.execAsync(dropDatabaseCommand)
      .then (stdout) ->
        # console.log stdout
        console.log 'setUp', 'create database'
        child_process.execAsync(createDatabaseCommand)
      .then (stdout) ->
        # console.log stdout
        stdout

    readSchema = fs.readFileAsync(
      path.resolve(__dirname, 'schema.sql')
      {encoding: 'utf8'}
    )
    Promise.join readSchema, resetDatabase, (schema) ->
        console.log 'setUp', 'migrate schema'
        mesa.query schema
      .then ->
        console.log 'setUp', 'END'
        done()

  'tearDown': (done) ->
    console.log 'tearDown', 'BEGIN'
    console.log 'tearDown', 'destroy pool'
    pgDestroyPool(DATABASE_URL)
      .then ->
        console.log 'tearDown', 'drop database'
        child_process.execAsync(dropDatabaseCommand)
      .then (stdout) ->
        console.log 'tearDown', 'END'
        done()

###################################################################################
# integration tests

  'just setUp and tearDown': (test) ->
    test.done()

  'getConnection': (test) ->
    mesa.getConnection().then ({connection, done}) ->
      test.ok connection?
      done()
      test.done()

  'query': (test) ->
    mesa.query('SELECT * FROM "user"').then (results) ->
      test.equal results.rows.length, 6
      test.done()

  'wrapInTransaction - commit': (test) ->
    test.expect 2
    mesa.wrapInTransaction(
      (transaction) ->
        withTransaction = mesa.setConnection transaction
        withTransaction
          .query('INSERT INTO "user"(name) VALUES ($1)', ['josie'])
          .then ->
            withTransaction.query('SELECT * FROM "user"')
          .then (results) ->
            test.equal results.rows.length, 7
    ).then ->
      mesa.query('SELECT * FROM "user"').then (results) ->
        test.equal results.rows.length, 7
        test.done()

  'wrapInTransaction - rollback': (test) ->
    test.expect 2
    mesa.wrapInTransaction(
      (transaction) ->
        withTransaction = mesa.setConnection transaction
        withTransaction
          .query('INSERT INTO "user"(name) VALUES ($1)', ['josie'])
          .then ->
            withTransaction.query('SELECT * FROM "user"')
          .then (results) ->
            test.equal results.rows.length, 7
            throw new Error 'rollback please'
    ).catch ->
      mesa.query('SELECT * FROM "user"').then (results) ->
        test.equal results.rows.length, 6
        test.done()

  'find all users': (test) ->
    test.expect 1
    mesa
      .table('user')
      .find()
      .then (rows) ->
        test.equal rows.length, 6
        test.done()

  'insert, read, update and delete a single user': (test) ->

    # exercising as much basic functionality as possible

    userTable = mesa
      .table('user')
      .allowedColumns(['name'])

    userTable.insert(name: 'josie').bind({})
      .then (row) ->
        @insertedRow = row
        test.equal @insertedRow.name, 'josie'
        userTable.where(name: 'josie').find()
      .then (rows) ->
        test.equal @insertedRow.id, rows[0].id
        userTable
          .where(id: @insertedRow.id)
          .returnFirst()
          .update(name: 'josie packer')
      .then (updatedRow) ->
        test.equal @insertedRow.id, updatedRow.id
        test.equal 'josie packer', updatedRow.name
        userTable
          .where(name: 'josie packer')
          .first()
      .then (row) ->
        test.equal 'josie packer', row.name
        userTable
          .where(id: @insertedRow.id)
          .returnFirst()
          .delete()
      .then (deletedRow) ->
        test.equal @insertedRow.id, deletedRow.id
        userTable.find()
      .then (rows) ->
        test.equal rows.length, 6

        test.done()

  'json and lateral joins': (test) ->
    # inspired by:
    # http://blog.heapanalytics.com/postgresqls-powerful-new-join-type-lateral/

    userTable = mesa
      .table('user')

    eventTable = mesa
      .table('event')
      .allowedColumns(['id', 'user_id', 'created_at', 'data'])

    userTable.where(name: 'laura').first()
      .then (laura) ->
        # insert a couple of events
        eventTable.insert([
          {
            user_id: laura.id
            created_at: mesa.raw('now()')
            data: JSON.stringify(type: 'view_homepage')
          }
      ])
      .then (events) ->
        console.log events

        innerQuery = eventTable
          .select(
            'user_id',
            {view_homepage: 1}
            {view_homepage_time: 'min(created_at)'}
          )
          .where("data->>'type' = ?", 'view_homepage')
          .group('user_id')
          .join('LEFT JOIN LATERAL')

        outerQuery = mesa
          .select([
            'user_id'
            'view_homepage'
            'view_homepage_time'
            'enter_credit_card'
            'enter_credit_card_time'
          ])
          .table(innerQuery)

        test.done()

  'subqueries (advisory locks)': (test) ->
    test.expect 7

    bitcoinReceiveAddress = mesa.table('bitcoin_receive_address')

    # locking the id and releasing it again
    # "xact" means that the lock is released at the end of the transaction
    selectUniqueAddressWithLock = bitcoinReceiveAddress
      .select('id')
      .where('pg_try_advisory_xact_lock(id) for update')
      .limit(1)

    addressPromises = [1..7].map ->
      mesa.wrapInTransaction (transaction) ->
        bitcoinReceiveAddress
          .setConnection(transaction)
          .where(id: selectUniqueAddressWithLock)
          .returnFirst()
          .delete()

    Promise.all(addressPromises).then (addresses) ->
      test.equal 34, addresses[0].address.length
      test.equal 34, addresses[1].address.length
      test.equal 34, addresses[2].address.length
      test.equal 34, addresses[3].address.length
      test.equal 34, addresses[4].address.length
      test.ok not addresses[5]?
      test.ok not addresses[6]?

      test.done()
