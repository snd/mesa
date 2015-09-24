Promise = require 'bluebird'

path = require 'path'
child_process = Promise.promisifyAll require 'child_process'
fs = Promise.promisifyAll require 'fs'

pg = require 'pg'

mesa = require '../../src/mesa'

###################################################################################
# constants

# for defaults
DATABASE_NAME = 'mesa_test'

DATABASE_URL = process.env.DATABASE_URL or "postgres://localhost/#{DATABASE_NAME}"

DROP_DATABASE = process.env.DROP_DATABASE or "psql -c 'DROP DATABASE IF EXISTS #{DATABASE_NAME};'"
CREATE_DATABASE = process.env.CREATE_DATABASE or "psql -c 'CREATE DATABASE #{DATABASE_NAME};'"

###################################################################################
# exports

module.exports =
  DATABASE_URL: DATABASE_URL

  mesa: mesa
    .setConnection (cb) -> pg.connect DATABASE_URL, cb
    # .debug (args...) -> console.log args[...3]...

  spy: (inner = ->) ->
    spy = (args...) ->
      spy.calls.push args
      return inner spy.calls, args...
    spy.calls = []
    return spy

  pgDestroyPool: (config) ->
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

  setup: (done) ->
    console.log 'setUp', 'BEGIN'
    console.log 'setUp', 'drop database'

    resetDatabase = child_process.execAsync(DROP_DATABASE)
      .then (stdout) ->
        # console.log stdout
        console.log 'setUp', 'create database'
        child_process.execAsync(CREATE_DATABASE)
      .then (stdout) ->
        # console.log stdout
        stdout

    readSchema = fs.readFileAsync(
      path.resolve(__dirname, 'schema.sql')
      {encoding: 'utf8'}
    )
    Promise.join readSchema, resetDatabase, (schema) ->
        console.log 'setUp', 'migrate schema'
        module.exports.mesa.query schema
      .then ->
        console.log 'setUp', 'END'
        done?()

  teardown: (done) ->
    console.log 'tearDown', 'BEGIN'
    console.log 'tearDown', 'destroy pool'

    module.exports.pgDestroyPool(DATABASE_URL)
      .then ->
        console.log 'tearDown', 'drop database'
        child_process.execAsync(DROP_DATABASE)
      .then (stdout) ->
        console.log 'tearDown', 'END'
        done?()