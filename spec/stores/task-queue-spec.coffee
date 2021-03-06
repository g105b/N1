Actions = require '../../src/flux/actions'
DatabaseStore = require '../../src/flux/stores/database-store'
TaskQueue = require '../../src/flux/stores/task-queue'
Task = require '../../src/flux/tasks/task'

{APIError,
 OfflineError,
 TimeoutError} = require '../../src/flux/errors'

class TaskSubclassA extends Task
  constructor: (val) -> @aProp = val; super

class TaskSubclassB extends Task
  constructor: (val) -> @bProp = val; super

describe "TaskQueue", ->

  makeUnstartedTask = (task) ->
    task

  makeProcessing = (task) ->
    task.queueState.isProcessing = true
    task

  beforeEach ->
    @task              = new Task()
    @unstartedTask     = makeUnstartedTask(new Task())
    @processingTask    = makeProcessing(new Task())

  afterEach ->
    # Flush any throttled or debounced updates
    advanceClock(1000)

  describe "restoreQueue", ->
    it "should fetch the queue from the database, reset flags and start processing", ->
      queue = [@processingTask, @unstartedTask]
      spyOn(DatabaseStore, 'findJSONBlob').andCallFake => Promise.resolve(queue)
      spyOn(TaskQueue, '_processQueue')

      waitsForPromise =>
        TaskQueue._restoreQueue().then =>
          expect(TaskQueue._queue).toEqual(queue)
          expect(@processingTask.queueState.isProcessing).toEqual(false)
          expect(TaskQueue._processQueue).toHaveBeenCalled()

  describe "findTask", ->
    beforeEach ->
      @subclassA = new TaskSubclassA()
      @subclassB1 = new TaskSubclassB("B1")
      @subclassB2 = new TaskSubclassB("B2")
      TaskQueue._queue = [@subclassA, @subclassB1, @subclassB2]

    it "accepts type as a string", ->
      expect(TaskQueue.findTask('TaskSubclassB', {bProp: 'B1'})).toEqual(@subclassB1)

    it "accepts type as a class", ->
      expect(TaskQueue.findTask(TaskSubclassB, {bProp: 'B1'})).toEqual(@subclassB1)

    it "works without a set of match criteria", ->
      expect(TaskQueue.findTask(TaskSubclassA)).toEqual(@subclassA)

    it "only returns a task that matches the criteria", ->
      expect(TaskQueue.findTask(TaskSubclassB, {bProp: 'B1'})).toEqual(@subclassB1)
      expect(TaskQueue.findTask(TaskSubclassB, {bProp: 'B2'})).toEqual(@subclassB2)
      expect(TaskQueue.findTask(TaskSubclassB, {bProp: 'B3'})).toEqual(null)

  describe "enqueue", ->
    beforeEach ->
      spyOn(@unstartedTask, 'runLocal').andCallFake =>
        @unstartedTask.queueState.localComplete = true
        Promise.resolve()

    it "makes sure you've queued a real task", ->
      expect( -> TaskQueue.enqueue("asamw")).toThrow()

    it "adds it to the queue", ->
      spyOn(TaskQueue, '_processQueue').andCallFake ->
      TaskQueue.enqueue(@unstartedTask)
      advanceClock()
      expect(TaskQueue._queue.length).toBe(1)

    it "immediately calls runLocal", ->
      TaskQueue.enqueue(@unstartedTask)
      expect(@unstartedTask.runLocal).toHaveBeenCalled()

    it "notifies the queue should be processed", ->
      spyOn(TaskQueue, "_processQueue").andCallThrough()
      spyOn(TaskQueue, "_processTask")

      TaskQueue.enqueue(@unstartedTask)
      advanceClock()
      advanceClock()
      expect(TaskQueue._processQueue).toHaveBeenCalled()
      expect(TaskQueue._processTask).toHaveBeenCalledWith(@unstartedTask)
      expect(TaskQueue._processTask.calls.length).toBe(1)

    it "throws an exception if the task does not have a queueState", ->
      task = new TaskSubclassA()
      task.queueState = undefined
      expect( => TaskQueue.enqueue(task)).toThrow()

    it "throws an exception if the task does not have an ID", ->
      task = new TaskSubclassA()
      task.id = undefined
      expect( => TaskQueue.enqueue(task)).toThrow()

    it "dequeues obsolete tasks", ->
      task = new TaskSubclassA()
      spyOn(TaskQueue, '_dequeueObsoleteTasks').andCallFake ->
      TaskQueue.enqueue(task)
      expect(TaskQueue._dequeueObsoleteTasks).toHaveBeenCalled()

  describe "_dequeueObsoleteTasks", ->
    it "should dequeue tasks based on `shouldDequeueOtherTask`", ->
      class KillsTaskA extends Task
        shouldDequeueOtherTask: (other) -> other instanceof TaskSubclassA
        performRemote: -> new Promise (resolve, reject) ->

      otherTask = new Task()
      otherTask.queueState.localComplete = true
      obsoleteTask = new TaskSubclassA()
      obsoleteTask.queueState.localComplete = true
      replacementTask = new KillsTaskA()
      replacementTask.queueState.localComplete = true

      spyOn(TaskQueue, 'dequeue').andCallThrough()
      TaskQueue._queue = [obsoleteTask, otherTask]
      TaskQueue._dequeueObsoleteTasks(replacementTask)
      expect(TaskQueue._queue.length).toBe(1)
      expect(obsoleteTask.queueState.status).toBe Task.Status.Continue
      expect(obsoleteTask.queueState.debugStatus).toBe Task.DebugStatus.DequeuedObsolete
      expect(TaskQueue.dequeue).toHaveBeenCalledWith(obsoleteTask)
      expect(TaskQueue.dequeue.calls.length).toBe(1)

  describe "dequeue", ->
    beforeEach ->
      TaskQueue._queue = [@unstartedTask, @processingTask]

    it "grabs the task by object", ->
      found = TaskQueue._resolveTaskArgument(@unstartedTask)
      expect(found).toBe @unstartedTask

    it "grabs the task by id", ->
      found = TaskQueue._resolveTaskArgument(@unstartedTask.id)
      expect(found).toBe @unstartedTask

    it "throws an error if the task isn't found", ->
      expect( -> TaskQueue.dequeue("bad")).toThrow()

    describe "with an unstarted task", ->
      it "moves it from the queue", ->
        TaskQueue.dequeue(@unstartedTask)
        expect(TaskQueue._queue.length).toBe(1)
        expect(TaskQueue._completed.length).toBe(1)

      it "notifies the queue has been updated", ->
        spyOn(TaskQueue, "_processQueue")
        TaskQueue.dequeue(@unstartedTask)
        advanceClock(20)
        advanceClock()
        expect(TaskQueue._processQueue).toHaveBeenCalled()
        expect(TaskQueue._processQueue.calls.length).toBe(1)

    describe "with a processing task", ->
      it "calls cancel() to allow the task to resolve or reject from runRemote()", ->
        spyOn(@processingTask, 'cancel')
        TaskQueue.dequeue(@processingTask)
        expect(@processingTask.cancel).toHaveBeenCalled()
        expect(TaskQueue._queue.length).toBe(2)
        expect(TaskQueue._completed.length).toBe(0)

  describe "process Task", ->
    it "doesn't process processing tasks", ->
      spyOn(@processingTask, "runRemote").andCallFake -> Promise.resolve()
      TaskQueue._processTask(@processingTask)
      expect(@processingTask.runRemote).not.toHaveBeenCalled()

    it "doesn't process blocked tasks", ->
      class BlockedByTaskA extends Task
        isDependentTask: (other) -> other instanceof TaskSubclassA

      taskA = new TaskSubclassA()
      otherTask = new Task()
      blockedByTaskA = new BlockedByTaskA()

      taskA.queueState.localComplete = true
      otherTask.queueState.localComplete = true
      blockedByTaskA.queueState.localComplete = true

      spyOn(taskA, "runRemote").andCallFake -> new Promise (resolve, reject) ->
      spyOn(blockedByTaskA, "runRemote").andCallFake -> Promise.resolve()

      TaskQueue._queue = [taskA, otherTask, blockedByTaskA]
      TaskQueue._processQueue()

      advanceClock()

      expect(TaskQueue._queue.length).toBe(2)
      expect(taskA.runRemote).toHaveBeenCalled()
      expect(blockedByTaskA.runRemote).not.toHaveBeenCalled()

    it "doesn't block itself, even if the isDependentTask method is implemented naively", ->
      class BlockingTask extends Task
        isDependentTask: (other) -> other instanceof BlockingTask

      blockedTask = new BlockingTask()
      spyOn(blockedTask, "runRemote").andCallFake -> Promise.resolve()

      TaskQueue.enqueue(blockedTask)
      advanceClock()
      blockedTask.runRemote.callCount > 0

    it "sets the processing bit", ->
      spyOn(@unstartedTask, "runRemote").andCallFake -> Promise.resolve()
      task = new Task()
      task.queueState.localComplete = true
      TaskQueue._queue = [task]
      TaskQueue._processTask(task)
      expect(task.queueState.isProcessing).toBe true

  describe "handling task runRemote task errors", ->
    spyAACallback = jasmine.createSpy("onDependentTaskError")
    spyBBRemote = jasmine.createSpy("performRemote")
    spyBBCallback = jasmine.createSpy("onDependentTaskError")
    spyCCRemote = jasmine.createSpy("performRemote")
    spyCCCallback = jasmine.createSpy("onDependentTaskError")

    beforeEach ->
      testError = new Error("Test Error")
      @testError = testError
      class TaskAA extends Task
        onDependentTaskError: spyAACallback
        performRemote: ->
          # We reject instead of `throw` because jasmine thinks this
          # `throw` is in the context of the test instead of the context
          # of the calling promise in task-queue.coffee
          return Promise.reject(testError)

      class TaskBB extends Task
        isDependentTask: (other) -> other instanceof TaskAA
        onDependentTaskError: spyBBCallback
        performRemote: spyBBRemote

      class TaskCC extends Task
        isDependentTask: (other) -> other instanceof TaskBB
        onDependentTaskError: (task, err) ->
          spyCCCallback(task, err)
          return Task.DO_NOT_DEQUEUE_ME
        performRemote: spyCCRemote

      @taskAA = new TaskAA
      @taskAA.queueState.localComplete = true
      @taskBB = new TaskBB
      @taskBB.queueState.localComplete = true
      @taskCC = new TaskCC
      @taskCC.queueState.localComplete = true

      spyOn(TaskQueue, 'trigger')

      # Don't keep processing the queue
      spyOn(TaskQueue, '_updateSoon')

    it "catches the error and dequeues the task", ->
      spyOn(TaskQueue, 'dequeue')
      waitsForPromise =>
        TaskQueue._processTask(@taskAA).then =>
          expect(TaskQueue.dequeue).toHaveBeenCalledWith(@taskAA)
          expect(spyAACallback).not.toHaveBeenCalled()
          expect(@taskAA.queueState.remoteError.message).toBe "Test Error"

    it "calls `onDependentTaskError` on dependent tasks", ->
      spyOn(TaskQueue, 'dequeue').andCallThrough()
      TaskQueue._queue = [@taskAA, @taskBB, @taskCC]
      waitsForPromise =>
        TaskQueue._processTask(@taskAA).then =>
          expect(TaskQueue.dequeue.calls.length).toBe 2
          # NOTE: The recursion goes depth-first. The leafs are called
          # first
          expect(TaskQueue.dequeue.calls[0].args[0]).toBe @taskBB
          expect(TaskQueue.dequeue.calls[1].args[0]).toBe @taskAA
          expect(spyAACallback).not.toHaveBeenCalled()
          expect(spyBBCallback).toHaveBeenCalledWith(@taskAA, @testError)
          expect(@taskAA.queueState.remoteError.message).toBe "Test Error"
          expect(@taskBB.queueState.status).toBe Task.Status.Continue
          expect(@taskBB.queueState.debugStatus).toBe Task.DebugStatus.DequeuedDependency

    it "dequeues all dependent tasks except those that return `Task.DO_NOT_DEQUEUE_ME` from their callbacks", ->
      spyOn(TaskQueue, 'dequeue').andCallThrough()
      TaskQueue._queue = [@taskAA, @taskBB, @taskCC]
      waitsForPromise =>
        TaskQueue._processTask(@taskAA).then =>
          expect(TaskQueue._queue).toEqual [@taskCC]
          expect(spyCCCallback).toHaveBeenCalledWith(@taskBB, @testError)
          expect(@taskCC.queueState.status).toBe null
          expect(@taskCC.queueState.debugStatus).toBe Task.DebugStatus.JustConstructed

