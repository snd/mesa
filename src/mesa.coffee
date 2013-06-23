mohair = require 'mohair'

associations = require './associations'

module.exports =

    # default
    # --------

    _mohair: mohair
    _primaryKey: 'id'

    # setter
    # ------

    set: (key, value) ->
        object = Object.create @
        object[key] = value
        object

    connection: (arg) -> @set '_connection', arg
    attributes: (arg) -> @set '_attributes', arg
    primaryKey: (arg) -> @set '_primaryKey', arg
    includes: (arg) -> @set '_includes', arg

    table: (arg) -> @set('_table', arg).set '_mohair', @_mohair.table arg

    # mohair passthroughs
    # -------------------

    sql: -> @_mohair.sql()
    params: -> @_mohair.params()

    raw: (args...) -> @_mohair.raw args...

    where: (args...) -> @set '_mohair', @_mohair.where args...
    join: (args...) -> @set '_mohair', @_mohair.join args...

    select: (args...) -> @set '_mohair', @_mohair.select args...
    limit: (arg) -> @set '_mohair', @_mohair.limit arg
    offset: (arg) -> @set '_mohair', @_mohair.offset arg
    order: (arg) -> @set '_mohair', @_mohair.order arg
    group: (arg) -> @set '_mohair', @_mohair.group arg

    # associations
    # ------------

    hasAssociated: associations.hasAssociated
    hasOne: associations.hasOne
    hasMany: associations.hasMany
    belongsTo: associations.belongsTo
    hasAndBelongsToMany: associations.hasAndBelongsToMany
    _getIncludes: associations._getIncludes
