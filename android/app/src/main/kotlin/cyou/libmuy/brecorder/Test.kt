package cyou.libmuy.brecorder

class Test {
    fun test1() {
        val th1 = TestThread("path")

        while (true) {
            Thread.sleep(1000)
            th1.start()
            Thread.sleep(5000)
            th1.recording = false
            th1.join()
        }

    }
}


class TestThread(path: String): Thread() {
    var recording = false
    override fun run() {
        recording = true
        while (recording) {
            Thread.sleep(1000)
            println("recording")
        }

        println("Recording stop")
    }
}


