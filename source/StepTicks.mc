import Toybox.Lang;

// Pure logic for the 60 ticks on the screen edge.
module StepTicks {

    const COUNT = 60;

    // The number of lit ticks for the progress to the step goal, from 0 to 60.
    function lit(steps as Number?, goal as Number?) as Number {
        if (steps == null || goal == null || goal <= 0) {
            return 0;
        }
        var ticks = (COUNT * steps) / goal;
        return (ticks > COUNT) ? COUNT : ticks;
    }
}
