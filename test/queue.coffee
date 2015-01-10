Promise = require 'bluebird'

{setup, teardown, mesa} = require './src/common'

module.exports =

  'adding to queueBeforeInsert works correctly': (test) ->
    instance = mesa

    beforeInsert = ->
    instance = instance.queueBeforeInsert beforeInsert
    test.equal instance._queueBeforeInsert.length, 1
    test.equal instance._queueBeforeInsert[0], beforeInsert

    test.ok not instance._queueBeforeUpdate?
    test.ok not instance.queueBeforeUpdate?

    test.done()

  'adding to queueBeforeEach* works correctly': (test) ->
    instance = mesa

    test.equal instance._queueBeforeEachInsert.length, 1
    test.equal instance._queueBeforeEachUpdate.length, 1
    test.equal instance._queueBeforeEachInsert[0], mesa.pickAllowed
    test.equal instance._queueBeforeEachUpdate[0], mesa.pickAllowed

    beforeEachInsert = ->
    instance = instance.queueBeforeEachInsert beforeEachInsert
    test.equal instance._queueBeforeEachInsert.length, 2
    test.equal instance._queueBeforeEachInsert[1], beforeEachInsert

    beforeEachUpdate = ->
    instance = instance.queueBeforeEachUpdate beforeEachUpdate
    test.equal instance._queueBeforeEachUpdate.length, 2
    test.equal instance._queueBeforeEachUpdate[1], beforeEachUpdate

    beforeEach = ->
    instance = instance.queueBeforeEach beforeEach
    test.equal instance._queueBeforeEachInsert.length, 3
    test.equal instance._queueBeforeEachInsert[2], beforeEach
    test.equal instance._queueBeforeEachUpdate.length, 3
    test.equal instance._queueBeforeEachUpdate[2], beforeEach

    test.done()

  'adding to queueAfter* works correctly': (test) ->
    instance = mesa

    after = ->
    instance = instance.queueAfter after
    test.equal instance._queueAfterSelect.length, 1
    test.equal instance._queueAfterSelect[0], after
    test.equal instance._queueAfterInsert.length, 1
    test.equal instance._queueAfterInsert[0], after
    test.equal instance._queueAfterUpdate.length, 1
    test.equal instance._queueAfterUpdate[0], after
    test.equal instance._queueAfterDelete.length, 1
    test.equal instance._queueAfterDelete[0], after

    afterSelect = ->
    instance = instance.queueAfterSelect afterSelect
    test.equal instance._queueAfterSelect.length, 2
    test.equal instance._queueAfterSelect[1], afterSelect

    afterInsert = ->
    instance = instance.queueAfterInsert afterInsert
    test.equal instance._queueAfterInsert.length, 2
    test.equal instance._queueAfterInsert[1], afterInsert

    afterUpdate = ->
    instance = instance.queueAfterUpdate afterUpdate
    test.equal instance._queueAfterUpdate.length, 2
    test.equal instance._queueAfterUpdate[1], afterUpdate

    afterDelete = ->
    instance = instance.queueAfterDelete afterDelete
    test.equal instance._queueAfterDelete.length, 2
    test.equal instance._queueAfterDelete[1], afterDelete

    test.done()

  'adding to queueAfterEach* works correctly': (test) ->
    instance = mesa

    after = ->
    instance = instance.queueAfterEach after
    test.equal instance._queueAfterEachSelect.length, 1
    test.equal instance._queueAfterEachSelect[0], after
    test.equal instance._queueAfterEachInsert.length, 1
    test.equal instance._queueAfterEachInsert[0], after
    test.equal instance._queueAfterEachUpdate.length, 1
    test.equal instance._queueAfterEachUpdate[0], after
    test.equal instance._queueAfterEachDelete.length, 1
    test.equal instance._queueAfterEachDelete[0], after

    afterSelect = ->
    instance = instance.queueAfterEachSelect afterSelect
    test.equal instance._queueAfterEachSelect.length, 2
    test.equal instance._queueAfterEachSelect[1], afterSelect

    afterInsert = ->
    instance = instance.queueAfterEachInsert afterInsert
    test.equal instance._queueAfterEachInsert.length, 2
    test.equal instance._queueAfterEachInsert[1], afterInsert

    afterUpdate = ->
    instance = instance.queueAfterEachUpdate afterUpdate
    test.equal instance._queueAfterEachUpdate.length, 2
    test.equal instance._queueAfterEachUpdate[1], afterUpdate

    afterDelete = ->
    instance = instance.queueAfterEachDelete afterDelete
    test.equal instance._queueAfterEachDelete.length, 2
    test.equal instance._queueAfterEachDelete[1], afterDelete

    test.done()

  'queues are executed correctly for insert': (test) ->
    test.expect 27
    input1 = {}
    input2 = {}
    input3 = {}
    input4 = {a: 1, b: 2, c: 3}

    output1 = {}
    output2 = {}
    output3 = {}
    output4 = {}

    row = {}
    rows = [row]
    results =
      rows: rows

    mesa = Object.create mesa
    mesa.query = (sql, params) ->
      test.equal sql, 'INSERT INTO "movie"("a", "b", "c") VALUES ($1, $2, $3) RETURNING *'
      test.deepEqual params, [1, 2, 3]
      return Promise.resolve results

    mesa
      .table('movie')
      .unsafe()
      .queueBeforeInsert ((arg1, arg2, arg3) ->
        test.equal arg1.length, 1
        test.equal arg1[0], input1
        test.equal arg2, 'arg2'
        test.equal arg3, 'arg3'
        [input2]
      ), 'arg2', 'arg3'
      .queueBeforeEachInsert ((arg1, arg2, arg3) ->
        test.equal arg1, input2
        test.equal arg2, 'arg2'
        test.equal arg3, 'arg3'
        Promise.resolve input3
      ), 'arg2', 'arg3'
      .queueBeforeEach ((arg1, arg2, arg3) ->
        test.equal arg1, input3
        test.equal arg2, 'arg2'
        test.equal arg3, 'arg3'
        input4
      ), 'arg2', 'arg3'
      .queueAfter ((arg1, arg2, arg3) ->
        test.equal arg1, rows
        test.equal arg2, 'arg2'
        test.equal arg3, 'arg3'
        Promise.resolve [output1]
      ), 'arg2', 'arg3'
      .queueAfterInsert ((arg1, arg2, arg3) ->
        test.equal arg1.length, 1
        test.equal arg1[0], output1
        test.equal arg2, 'arg2'
        test.equal arg3, 'arg3'
        [output2]
      ), 'arg2', 'arg3'
      .queueAfterEach ((arg1, arg2, arg3) ->
        test.equal arg1, output2
        test.equal arg2, 'arg2'
        test.equal arg3, 'arg3'
        output3
      ), 'arg2', 'arg3'
      .queueAfterEachInsert ((arg1, arg2, arg3) ->
        test.equal arg1, output3
        test.equal arg2, 'arg2'
        test.equal arg3, 'arg3'
        output4
      ), 'arg2', 'arg3'
      .insert([input1])
      .then (outputs) ->
        test.equal outputs.length, 1
        test.equal outputs[0], output4
        test.done()

  'queues are executed correctly for update': (test) ->
    test.expect 11
    input1 = {}
    input2 = {}
    input3 = {a: 1, b: 2, c: 3}

    output1 = {}
    output2 = {}
    output3 = {}
    output4 = {}

    row = {}
    rows = [row]
    results =
      rows: rows

    mesa = Object.create mesa
    mesa.query = (sql, params) ->
      test.equal sql, 'UPDATE "movie" SET "a" = $1, "b" = $2, "c" = $3 RETURNING *'
      test.deepEqual params, [1, 2, 3]
      return Promise.resolve results

    mesa
      .table('movie')
      .unsafe()
      .queueBeforeEachUpdate ((arg1) ->
        test.equal arg1, input1
        Promise.resolve input2
      )
      .queueBeforeEach ((arg1) ->
        test.equal arg1, input2
        input3
      )
      .queueAfter ((arg1) ->
        test.equal arg1, rows
        Promise.resolve [output1]
      )
      .queueAfterUpdate ((arg1) ->
        test.equal arg1.length, 1
        test.equal arg1[0], output1
        [output2]
      )
      .queueAfterEach ((arg1) ->
        test.equal arg1, output2
        output3
      )
      .queueAfterEachUpdate ((arg1) ->
        test.equal arg1, output3
        output4
      )
      .update(input1)
      .then (outputs) ->
        test.equal outputs.length, 1
        test.equal outputs[0], output4
        test.done()

  'queues are executed correctly for select': (test) ->
    test.expect 9

    output1 = {}
    output2 = {}
    output3 = {}
    output4 = {}

    row = {}
    rows = [row]
    results =
      rows: rows

    mesa = Object.create mesa
    mesa.query = (sql, params) ->
      test.equal sql, 'SELECT * FROM "movie"'
      test.deepEqual params, []
      return Promise.resolve results

    mesa
      .table('movie')
      .unsafe()
      .queueAfter ((arg1) ->
        test.equal arg1, rows
        Promise.resolve [output1]
      )
      .queueAfterSelect ((arg1) ->
        test.equal arg1.length, 1
        test.equal arg1[0], output1
        [output2]
      )
      .queueAfterEach ((arg1) ->
        test.equal arg1, output2
        output3
      )
      .queueAfterEachSelect ((arg1) ->
        test.equal arg1, output3
        output4
      )
      .find()
      .then (outputs) ->
        test.equal outputs.length, 1
        test.equal outputs[0], output4
        test.done()

  'queues are executed correctly for delete': (test) ->
    test.expect 8

    output1 = {}
    output2 = {}
    output3 = {}
    output4 = {}

    row = {}
    rows = [row]
    results =
      rows: rows

    mesa = Object.create mesa
    mesa.query = (sql, params) ->
      test.equal sql, 'DELETE FROM "movie" RETURNING *'
      test.deepEqual params, []
      return Promise.resolve results

    mesa
      .table('movie')
      .unsafe()
      .queueAfter ((arg1) ->
        test.equal arg1, rows
        Promise.resolve [output1]
      )
      .queueAfterDelete ((arg1) ->
        test.equal arg1.length, 1
        test.equal arg1[0], output1
        [output2]
      )
      .queueAfterEach ((arg1) ->
        test.equal arg1, output2
        output3
      )
      .queueAfterEachDelete ((arg1) ->
        test.equal arg1, output3
        output4
      )
      .returnFirst()
      .delete()
      .then (output) ->
        test.equal output, output4
        test.done()
