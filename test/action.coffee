{setup, teardown, mesa, spy} = require './src/common'

userTable = mesa.table('user')

module.exports =

  'setUp': setup
  'tearDown': teardown

################################################################################
# query

  'query': (test) ->
    debug = spy()
    mesa
      .debug(debug)
      .query('SELECT * FROM "user"').then (results) ->
        test.equal results.rows.length, 6
        test.equal debug.calls.length, 4
        test.done()

  'query with params': (test) ->
    debug = spy()
    mesa
      .debug(debug)
      .query('SELECT * FROM "user" WHERE name = $1', ['laura']).then (results) ->
        test.equal results.rows.length, 1
        test.equal debug.calls.length, 4
        test.done()

################################################################################
# find

  'find': (test) ->
    debug = spy()
    userTable
      .debug(debug)
      .find()
      .then (rows) ->
        test.equal rows.length, 6
        test.equal debug.calls.length, 6
        test.done()

################################################################################
# first

  'first': (test) ->
    debug = spy()
    userTable
      .debug(debug)
      .where(name: 'audrey')
      .first()
      .then (row) ->
        test.equal row.name, 'audrey'
        test.equal debug.calls.length, 6
        test.done()

################################################################################
# exists

  'exists': (test) ->
    debug = spy()
    userTable
      .debug(debug)
      .where(name: 'audrey')
      .exists()
      .then (exists) ->
        test.ok exists
        test.equal debug.calls.length, 4
        test.done()

  'not exists': (test) ->
    debug = spy()
    userTable
      .debug(debug)
      .where(name: 'josie')
      .exists()
      .then (exists) ->
        test.ok not exists
        test.equal debug.calls.length, 4
        test.done()

################################################################################
# insert

  'insert one': (test) ->
    debug = spy()

    userTable
      .debug(debug)
      .allow(['name'])
      .insert(name: 'josie')
      .then (row) ->
        test.equal row.name, 'josie'
        test.equal debug.calls.length, 8
        test.done()

  'insert many': (test) ->
    debug = spy()

    userTable
      .debug(debug)
      .allow('name')
      .insert([
        {name: 'josie'}
        {name: 'jake'}
      ])
      .then (rows) ->
        test.equal rows.length, 2
        test.equal rows[0].name, 'josie'
        test.equal rows[1].name, 'jake'
        test.equal debug.calls.length, 8
        test.done()

  'insert unsafe': (test) ->
    debug = spy()

    userTable
      .debug(debug)
      .unsafe()
      .insert(name: 'josie')
      .then (row) ->
        test.equal row.name, 'josie'
        test.equal debug.calls.length, 8
        test.done()

################################################################################
# update

  'update with effect': (test) ->
    debug = spy()

    userTable
      .debug(debug)
      .allow('name')
      .where(name: 'audrey')
      .returnFirst()
      .update(name: 'josie')
      .then (row) ->
        test.equal row.name, 'josie'
        test.equal debug.calls.length, 8
        test.done()

  'update unsafe with effect': (test) ->
    debug = spy()

    userTable
      .debug(debug)
      .unsafe()
      .where(name: 'audrey')
      .update(name: 'josie')
      .then (rows) ->
        test.equal rows.length, 1
        test.equal rows[0].name, 'josie'
        test.equal debug.calls.length, 8
        test.done()

  'update without effect': (test) ->
    debug = spy()

    userTable
      .debug(debug)
      .allow('name')
      .where(name: 'josie')
      .update(name: 'audrey')
      .then (rows) ->
        test.equal rows.length, 0
        test.equal debug.calls.length, 8
        test.done()

################################################################################
# delete

  'delete with effect': (test) ->
    debug = spy()

    userTable
      .debug(debug)
      .where(name: 'audrey')
      .returnFirst()
      .delete()
      .then (row) ->
        test.equal row.name, 'audrey'
        test.equal debug.calls.length, 6
        test.done()

  'delete without effect': (test) ->
    debug = spy()

    userTable
      .debug(debug)
      .where(name: 'josie')
      .delete()
      .then (rows) ->
        test.equal rows.length, 0
        test.equal debug.calls.length, 6
        test.done()

################################################################################
# all actions together

  'all actions together': (test) ->

    userTable = mesa
      .table('user')
      .allow(['name'])

    userTable.insert(name: 'josie').bind({})
      .then (row) ->
        @insertedRow = row
        test.equal @insertedRow.name, 'josie'
        userTable.where(name: 'josie').find()
      .then (rows) ->
        test.equal @insertedRow.id, rows[0].id
        console.log '@insertedRow', @insertedRow
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
