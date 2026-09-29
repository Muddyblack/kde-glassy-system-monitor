import QtQuick
import QtTest
import "../package/contents/ui" as Shared

TestCase {
    name: "PlasmaCommands"
    property QtObject pendingJob: null
    Component {
        id: adapter
        Shared.PlasmaCommandSource {}
    }
    SignalSpy {
        id: results
        signalName: "newData"
    }
    function init() {
        results.clear();
    }
    function cleanup() {
        results.target = null;
        pendingJob = null;
    }

    function test_completedCommandsReleaseTheirSources() {
        const worker = createTemporaryObject(adapter, this);
        results.target = worker;
        for (let i = 0; i < 100; i++) {
            const source = "printf ok # " + i;
            worker.connectSource(source);
            const job = worker._jobs[source];
            verify(job !== undefined);
            pendingJob = job;
            worker.connectSource(source);
            compare(worker.connectedSources.length, 1, "Duplicate calls must share the running job");
            job.newData(source, {
                stdout: "ok"
            });
            compare(worker.connectedSources.length, 0);
            compare(Object.keys(worker._jobs).length, 0);
            wait(1); // Flush deferred QObject destruction.
            compare(pendingJob, null, "Completed DataSource maps must be destroyed");
        }
        compare(results.count, 100);
    }

    function test_cancelRejectsLateResultsAndPreservesOtherJobs() {
        const worker = createTemporaryObject(adapter, this);
        results.target = worker;
        const source = "printf first";
        const other = "printf second";
        worker.connectSource(source);
        worker.connectSource(other);
        const stale = worker._jobs[source];
        worker.cancelSource(source);
        compare(worker.connectedSources, [other]);
        worker.connectSource(source);
        const current = worker._jobs[source];
        verify(current !== stale);
        stale.newData(source, {
            stdout: "old"
        });
        compare(results.count, 0);
        compare(worker._jobs[source], current);
        current.newData(source, {
            stdout: "fresh"
        });
        compare(results.count, 1);
        compare(results.signalArguments[0][1].stdout, "fresh");
        compare(worker.connectedSources, [other]);
        worker.cancelSource(other);
        compare(Object.keys(worker._jobs).length, 0);
    }
}
