{setup, teardown, mesa, spy} = require './src/common'

module.exports =

  'setUp': setup
  'tearDown': teardown

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

    beforeEachAlpha = ->
    beforeEachBravo = ->
    instance = instance.queueBeforeEach beforeEachAlpha, beforeEachBravo
    test.equal instance._queueBeforeEachInsert.length, 4
    test.equal instance._queueBeforeEachInsert[2], beforeEachAlpha
    test.equal instance._queueBeforeEachInsert[3], beforeEachBravo
    test.equal instance._queueBeforeEachUpdate.length, 4
    test.equal instance._queueBeforeEachUpdate[2], beforeEachAlpha
    test.equal instance._queueBeforeEachUpdate[3], beforeEachBravo

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

  'adding to queueAfterEach works correctly': (test) ->
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

  'before queues are executed correctly for insert': (test) ->
    test.done()

  'before queues are executed correctly for update': (test) ->
    test.done()

  'after queues are executed correctly for select': (test) ->
    test.done()

  'after queues are executed correctly for insert': (test) ->
    test.done()

  'after queues are executed correctly for update': (test) ->
    test.done()

  'after queues are executed correctly for delete': (test) ->
    test.done()

#
#   'omit sensitive': (test) ->
#
#   'camelcase snakecase': (test) ->
#
#   'if queue fails all fails': (test) ->
#
#     hashPassword
#       .before
#
#     test.done()
