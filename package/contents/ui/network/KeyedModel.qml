import QtQuick

// A ListModel kept in step with an array of { key, … } rows by key, so live
// lists update in place: scroll position, selection and open rows survive
// every poll. Each item has `key` and `row` (the object).
ListModel {
    id: model
    dynamicRoles: true
    property var rows: []
    onRowsChanged: sync(rows)

    // A mirror of the keys keeps every lookup a native indexOf instead of
    // a get() per row.
    function sync(list) {
        const keys = [];
        for (let i = 0; i < count; i++)
            keys.push(get(i).key);
        for (let i = 0; i < list.length; i++) {
            const key = list[i].key;
            if (keys[i] === key) {
                setProperty(i, "row", list[i]);
                continue;
            }
            const j = keys.indexOf(key, i + 1);
            if (j >= 0) {
                move(j, i, 1);
                keys.splice(i, 0, keys.splice(j, 1)[0]);
                setProperty(i, "row", list[i]);
            } else {
                insert(i, {
                    key: key,
                    row: list[i]
                });
                keys.splice(i, 0, key);
            }
        }
        if (count > list.length)
            remove(list.length, count - list.length);
    }
}
