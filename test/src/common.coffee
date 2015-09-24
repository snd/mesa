Promise = require 'bluebird'

path = require 'path'
child_process = Promise.promisifyAll require 'child_process'
fs = Promise.promisifyAll require 'fs'

pg = require 'pg'

mesa = require '../../lib/mesa'

###################################################################################
# exports

module.exports =
  mesa: mesa.setConnection (cb) -> pg.connect process.env.DATABASE_URL, cb
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

    resetDatabase = child_process.execAsync(process.env.DROP_DATABASE)
      .then (stdout) ->
        # console.log stdout
        console.log 'setUp', 'create database'
        child_process.execAsync(process.env.CREATE_DATABASE)
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

    module.exports.pgDestroyPool(process.env.DATABASE_URL)
      .then ->
        console.log 'tearDown', 'drop database'
        child_process.execAsync(process.env.DROP_DATABASE)
      .then (stdout) ->
        console.log 'tearDown', 'END'
        done?()
