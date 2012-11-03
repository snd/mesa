mohair = require('mohair').escapeTableName((tableName) -> "\"#{tableName}\"")
_ = require 'underscore'
async = require 'async'

module.exports =

    # adapter
    # -------

    replacePlaceholders: (sql) ->
        # replace ?, ?, ... with $1, $2, ...
        index = 1
        sql.replace /\?/g, -> '$' + index++

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

    table: (arg) -> @set('_table', arg).set '_mohair', @_mohair.table arg

    connection: (arg) -> @set '_connection', arg
    attributes: (arg) -> @set '_attributes', arg
    primaryKey: (arg) -> @set '_primaryKey', arg
    includes: (arg) -> @set '_includes', arg

    where: (args...) -> @set '_mohair', @_mohair.where args...
    join: (args...) -> @set '_mohair', @_mohair.join args...

    select: (arg) -> @set '_mohair', @_mohair.select arg
    limit: (arg) -> @set '_mohair', @_mohair.limit arg
    offset: (arg) -> @set '_mohair', @_mohair.offset arg
    order: (arg) -> @set '_mohair', @_mohair.order arg
    group: (arg) -> @set '_mohair', @_mohair.group arg

    # getter
    # ------

    getConnection: (cb) ->
        connection = @_connection
        unless connection?
            throw new Error "the method you are calling requires a call to connection() before it"
        return connection cb if 'function' is typeof connection
        process.nextTick -> cb null, connection

    # command
    # -------

    insert: (data, cb) ->
        unless @_attributes?
            throw new Error 'insert() requires call to attributes() before it'

        cleanData = _.pick data, @_attributes
        if Object.keys(cleanData).length is 0
            throw new Error 'nothing to insert'

        query = @_mohair.insert cleanData
        sql = @replacePlaceholders query.sql() + " RETURNING #{@_primaryKey}"

        @getConnection (err, connection) ->
            return cb err if err?

            connection.query sql, query.params(), (err, results) ->
                return cb err if err?

                cb null, results.rows[0].id

    insertMany: (data, cb) ->
        unless @_attributes?
            throw new Error 'insertMany() requires call to attributes() before it'

        query = @_mohair.insert data.map (x) => _.pick x, @_attributes
        sql = @replacePlaceholders query.sql() + " RETURNING #{@_primaryKey}"

        @getConnection (err, connection) ->
            return cb err if err?

            connection.query sql, query.params(), (err, results) ->
                return cb err if err?

                cb null, _.pluck results.rows, 'id'

    delete: (cb) ->
        query = @_mohair.delete()
        sql = @replacePlaceholders query.sql()

        @getConnection (err, connection) ->
            return cb err if err?

            connection.query sql, query.params(), cb

    update: (updates, cb) ->
        unless @_attributes?
            throw new Error 'update() requires call to attributes() before it'

        cleanUpdates = _.pick updates, @_attributes
        throw new Error 'nothing to update' if Object.keys(cleanUpdates).length is 0

        query =  @_mohair.update cleanUpdates
        sql = @replacePlaceholders query.sql()

        @getConnection (err, connection) ->
            return cb err if err?

            connection.query sql, query.params(), cb

    # query
    # -----

    first: (cb) ->
        query =  @_mohair
        sql = @replacePlaceholders query.sql()

        @getConnection (err, connection) =>
            return cb err if err?

            connection.query sql, query.params(), (err, results) =>
                return cb err if err?

                item = results.rows[0]

                return cb null, null if not item?

                @fetchIncludes connection, [item], (err, withIncludes) =>
                    return cb err if err?
                    cb null, withIncludes[0]

    find: (cb) ->
        query =  @_mohair
        sql = @replacePlaceholders query.sql()

        @getConnection (err, connection) =>
            return cb err if err?

            connection.query sql, query.params(), (err, results) =>
                return cb err if err?

                items = results.rows

                return cb null, [] if items.length is 0

                @fetchIncludes connection, items, (err, withIncludes) =>
                    return cb err if err?

                    cb null, withIncludes

    exists: (cb) ->
        query =  @_mohair
        sql = @replacePlaceholders query.sql()

        @getConnection (err, connection) =>
            return cb err if err?

            connection.query sql, query.params(), (err, results) ->
                return cb err if err?

                cb null, results.rows.length isnt 0

    # association
    # -----------

    _addAssociation: (type, name, model, options) ->
        associations = _.extend {}, @_associations
        associations[name] =
            type: type
            model: model
            options: options
        @set '_associations', associations

    hasOne: (name, model, options) ->
        @_addAssociation 'hasOne', name, model, options

    belongsTo: (name, model, options) ->
        @_addAssociation 'belongsTo', name, model, options

    hasMany: (name, model, options) ->
        @_addAssociation 'hasMany', name, model, options

    hasAndBelongsToMany: (name, model, options) ->
        @_addAssociation 'hasAndBelongsToMany', name, model, options

    fetchIncludes: (connection, items, cb) ->
        that = this
        return cb null, items unless that._includes?

        includeNames = Object.keys that._includes

        throw new Error 'empty includes' if includeNames.length is 0

        includeNames.forEach (x) ->
            unless that._associations? and that._associations[x]?
                throw new Error "no association: #{x}"

        throw new Error 'no table set on model' unless that._table?

        fetchInclude = (includeName, cb) ->

            association = that._associations[includeName]

            otherModel =
                if 'function' is typeof association.model then association.model() else association.model
            otherTable = otherModel._table
            throw new Error 'no table set on associated model' unless otherTable?

            chain = otherModel.connection connection

            # fetch nested includes
            if 'object' is typeof that._includes[includeName]
                chain = chain.includes that._includes[includeName]

            fetchDirect = (key, otherKey, filter, cb) ->
                criterion = {}
                criterion[otherKey] = _.unique _.pluck items, key

                chain.where(criterion).find (err, associated) ->
                    return cb err if err?

                    items.forEach (item) ->
                        item[includeName] = filter associated, (x) ->
                            x[otherKey] is item[key]
                    cb null, items

            primaryKey = association.options?.primaryKey || 'id'
            foreignKey = association.options?.foreignKey

            switch association.type
                when 'hasOne'
                    fetchDirect primaryKey, (foreignKey || "#{that._table}_id"), _.detect, cb
                when 'hasMany'
                    fetchDirect primaryKey, (foreignKey || "#{that._table}_id"), _.filter, cb
                when 'belongsTo'
                    fetchDirect (foreignKey || "#{otherTable}_id"), primaryKey, _.detect, cb
                when 'hasAndBelongsToMany'
                    joinTable = association.options.joinTable
                    throw new Error 'no join table' unless joinTable?

                    foreignKey ?= "#{that._table}_id"
                    intersectionCriterion = {}
                    intersectionCriterion[foreignKey] = _.pluck items, primaryKey
                    m = mohair.table(joinTable).where(intersectionCriterion)
                    sql = that.replacePlaceholders m.sql()
                    connection.query sql, m.params(), (err, results) ->
                        return cb err if err?

                        intersection = results.rows

                        otherPrimaryKey = association.options?.otherPrimaryKey || 'id'
                        otherForeignKey = association.options?.otherForeignKey || "#{otherTable}_id"

                        criterion = {}
                        criterion[otherPrimaryKey] =
                            _.unique _.pluck intersection, otherForeignKey

                        chain.where(criterion).find (err, associated) ->
                            return cb err if err?
                            items.forEach (item) ->
                                relevantIntersection = _.filter intersection, (x) ->
                                    x[foreignKey] is item[primaryKey]
                                otherPrimaryKeys = _.pluck relevantIntersection, otherForeignKey
                                item[includeName] = associated.filter (x) ->
                                    x[otherPrimaryKey] in otherPrimaryKeys
                            cb null, items
                else
                    throw new Error "unknown association type: #{association.type}"

        async.forEachSeries includeNames, fetchInclude, (err) ->
            return cb err if err?
            cb null, items
