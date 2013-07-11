_ = require 'underscore'
mohair = require 'mohair'

createCriterion = (pk, fk, records) ->
    criterion = {}
    criterion[fk] = _.unique _.pluck records, pk
    return criterion

setOneInclude = (name, pk, fk, records, associated) ->
    records.forEach (record) ->
        record[name] = _.detect associated, (x) -> record[fk] is x[pk]

setManyIncludes = (name, pk, fk, records, associated) ->
    records.forEach (record) ->
        record[name] = _.filter associated, (x) -> record[fk] is x[pk]

module.exports =
    _prepareAssociatedTable: (table, subIncludes) ->
        self = this
        localTable = if 'function' is typeof table then table() else table
        localTable = localTable.includes subIncludes if 'object' is typeof subIncludes
        if self.enableConnectionReuseForIncludes
            localTable = localTable.connection self._connection
        return localTable

    # association
    # -----------

    hasAssociated: (name, associationFun) ->
        self = this
        associations = _.extend {}, self._associations
        associations[name] = associationFun
        self.set '_associations', associations

    _getIncludes: (records, cb) ->
        self = this

        unless self._includes?
            process.nextTick ->
                cb null, records
            return

        keysToFetch = Object.keys self._includes

        throw new Error 'empty includes' if keysToFetch.length is 0

        keysToFetch.forEach (key) ->
            unless self._associations? and self._associations[key]?
                throw new Error "no association: #{key}"

        if self.enableParallelIncludes
            self.hookBeforeIncludes? self, keysToFetch

            if keysToFetch.length is 0
                self.hookAfterIncludes? self, keysToFetch
                cb null, records
                return

            firstError = null
            doneCount = 0

            keysToFetch.forEach (key) ->
                self.hookBeforeInclude? self, key
                self._associations[key].call self, self._includes[key], records, (err) ->
                    self.hookAfterInclude? self, key
                    doneCount++
                    if err?
                        unless firstError?
                            firstError = err
                    if doneCount is keysToFetch.length
                        if firstError?
                            cb firstError
                        else
                            cb null, records
        else
            fetchKeys = (keys) ->
                if keys.length is 0
                    self.hookAfterIncludes? self, keysToFetch
                    cb null, records
                    return

                key = keys[0]
                rest = keys.slice 1

                self.hookBeforeInclude? self, key
                self._associations[key].call self, self._includes[key], records, (err) ->
                    self.hookAfterInclude? self, key
                    if err?
                        cb err
                        return

                    fetchKeys rest

            self.hookBeforeIncludes? self, keysToFetch
            fetchKeys keysToFetch

    hasOne: (name, associatedTable, options) ->
        this.hasAssociated name, (subIncludes, records, cb) ->
            self = this

            localAssociatedTable = self._prepareAssociatedTable associatedTable, subIncludes

            primaryKey = options?.primaryKey || self._primaryKey
            foreignKey = options?.foreignKey || "#{self._table}_#{self._primaryKey}"

            criterion = createCriterion primaryKey, foreignKey, records

            self.hookBeforeHasOne? name, self, localAssociatedTable
            localAssociatedTable.where(criterion).find (err, associated) ->
                self.hookAfterHasOne? name, self, localAssociatedTable, err, associated

                return cb err if err?

                setOneInclude name, foreignKey, primaryKey, records, associated
                cb null, records

    hasMany: (name, associatedTable, options) ->
        this.hasAssociated name, (subIncludes, records, cb) ->
            self = this

            localAssociatedTable = self._prepareAssociatedTable associatedTable, subIncludes

            primaryKey = options?.primaryKey || self._primaryKey
            foreignKey = options?.foreignKey || "#{self._table}_#{self._primaryKey}"

            criterion = createCriterion primaryKey, foreignKey, records

            self.hookBeforeHasMany? name, self, localAssociatedTable
            localAssociatedTable.where(criterion).find (err, associated) ->
                self.hookAfterHasMany? name, self, localAssociatedTable, err, associated

                return cb err if err?

                setManyIncludes name, foreignKey, primaryKey, records, associated
                cb null, records

    belongsTo: (name, associatedTable, options) ->
        this.hasAssociated name, (subIncludes, records, cb) ->
            self = this

            localAssociatedTable = self._prepareAssociatedTable associatedTable, subIncludes

            primaryKey = options?.primaryKey || self._primaryKey
            foreignKey = options?.foreignKey || "#{localAssociatedTable._table}_#{localAssociatedTable._primaryKey}"

            criterion = createCriterion foreignKey, primaryKey, records

            self.hookBeforeBelongsTo? name, self, localAssociatedTable
            localAssociatedTable.where(criterion).find (err, associated) ->
                self.hookAfterBelongsTo? name, self, localAssociatedTable, err, associated

                return cb err if err?

                setOneInclude name, primaryKey, foreignKey, records, associated
                cb null, records

    hasManyThrough: (name, associatedTable, joinTable, options) ->
        this.hasAssociated name, (subIncludes, records, cb) ->
            self = this

            localAssociatedTable = self._prepareAssociatedTable associatedTable, subIncludes

            primaryKey = options?.primaryKey || self._primaryKey
            foreignKey = options?.foreignKey || "#{self._table}_#{self._primaryKey}"

            otherPrimaryKey = options?.otherPrimaryKey || localAssociatedTable._primaryKey
            otherForeignKey = options?.otherForeignKey || "#{localAssociatedTable._table}_#{localAssociatedTable._primaryKey}"

            intersectionCriterion =
                createCriterion primaryKey, foreignKey, records

            localJoinTable = self._prepareAssociatedTable joinTable
            localJoinTable = localJoinTable.where(intersectionCriterion)

            self.hookBeforeHasManyThroughJoinTable? name, self, localAssociatedTable, localJoinTable
            localJoinTable.find (err, intersection) ->
                self.hookAfterHasManyThroughJoinTable? name, self, localAssociatedTable, localJoinTable, err, results

                return cb err if err?

                records.forEach (record) -> record[name] = []

                if intersection.length is 0
                    return cb null, records

                criterion =
                    createCriterion otherForeignKey, otherPrimaryKey, intersection

                self.hookBeforeHasManyThrough? name, self, localAssociatedTable, localJoinTable
                localAssociatedTable.where(criterion).find (err, associated) ->
                    self.hookAfterHasManyThrough? name, self, localAssociatedTable, localJoinTable, err, associated
                    return cb err if err?

                    records.forEach (record) ->
                        relevantIntersection = _.filter intersection, (x) ->
                            x[foreignKey] is record[primaryKey]
                        otherPrimaryKeys = _.pluck relevantIntersection, otherForeignKey
                        record[name] = associated.filter (x) ->
                            x[otherPrimaryKey] in otherPrimaryKeys

                    cb null, records
