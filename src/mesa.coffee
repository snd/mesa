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
        object = Object.create this
        object[key] = value
        object

    connection: (arg) ->
        this.set '_connection', arg
    attributes: (arg) ->
        this.set '_attributes', arg
    primaryKey: (arg) ->
        this.set '_primaryKey', arg
    includes: (arg) ->
        this.set '_includes', arg

    table: (arg) ->
        this.set('_table', arg).set '_mohair', this._mohair.table arg

    # mohair passthroughs
    # -------------------

    sql: ->
        this._mohair.sql()
    params: ->
        this._mohair.params()

    raw: (args...) ->
        this._mohair.raw args...

    where: (args...) ->
        this.set '_mohair', this._mohair.where args...
    join: (args...) ->
        this.set '_mohair', this._mohair.join args...

    select: (args...) ->
        this.set '_mohair', this._mohair.select args...
    limit: (arg) ->
        this.set '_mohair', this._mohair.limit arg
    offset: (arg) ->
        this.set '_mohair', this._mohair.offset arg
    order: (arg) ->
        this.set '_mohair', this._mohair.order arg
    group: (arg) ->
        this.set '_mohair', this._mohair.group arg
    with: (arg) ->
        this.set '_mohair', this._mohair.with arg

    # misc
    # ----

    assertTable: ->
        unless this._table?
            throw new Error 'mesa requires `table()` to be called before an insert, update or delete query'

    assertConnection: ->
        unless this._connection?
            throw new Error 'mesa requires `connection()` to be called before any query'

    assertAttributes: ->
        unless this._attributes?
            throw new Error 'mesa requires `attributes()` to be called before an insert or update query'

    # associations
    # ------------


    enableConnectionReuseForIncludes: false
    enableParallelIncludes: false

    hasAssociated: associations.hasAssociated
    hasOne: associations.hasOne
    hasMany: associations.hasMany
    belongsTo: associations.belongsTo
    hasManyThrough: associations.hasManyThrough
    hasOneThrough: associations.hasOneThrough

    _getIncludes: associations._getIncludes
    _prepareAssociatedTable: associations._prepareAssociatedTable
