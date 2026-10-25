package io.freemytv;

import android.app.job.JobInfo;
import android.app.job.JobParameters;
import android.app.job.JobScheduler;
import android.app.job.JobService;
import android.content.ComponentName;
import android.content.Context;
import android.os.PersistableBundle;

/**
 * Runs the mode switches in the background (HomeMode). As a job, the system keeps the app's main process running until
 * the switch finishes, even with the screen showing something else.
 */
public class ModeJob extends JobService {
    static final String APPLY = "apply", VERIFY = "verify", REVERT = "revert", MEMORY = "memory", REMOTE = "remote";
    // Explicit safety lock: remain false until P-04 validates factory launcher rollback.
    // Stops ALL ADB-backed jobs, including boot/update/recovery jobs. Do not toggle
    // for a release before confirming behavior on the actual Xiaomi firmware.
    static final boolean PROJECTOR_HOME_SWITCH_AUDITED = false;
    // Independent gate: a future verified rollback must not require enabling
    // potentially destructive HOME/APPLY/VERIFY behavior. Also locked for P-05.
    static final boolean PROJECTOR_RECOVERY_AUDITED = false;

    private static boolean permitted(String action) {
        if (REVERT.equals(action)) return PROJECTOR_RECOVERY_AUDITED;
        return PROJECTOR_HOME_SWITCH_AUDITED;
    }

    @Override public boolean onStartJob(JobParameters params) {
        PersistableBundle extras = params.getExtras();
        final String action = extras.getString("action", "");
        if (!permitted(action)) return false;
        final String mode = extras.getString("mode", "");
        final Context app = getApplicationContext();
        new Thread(() -> {
            try {
                switch (action) {
                    case APPLY: HomeMode.applyNow(app, mode); break;
                    case VERIFY: HomeMode.verifyNow(app); break;
                    case REVERT: HomeMode.revertHomeNow(app); break;
                    case MEMORY: HomeMode.measureMemoryNow(app, mode); break;
                    case REMOTE: HomeMode.ensureRemoteServiceNow(app); break;
                    default: break;
                }
            } catch (Throwable t) {
                AppLog.w("job " + action + " failed: " + t);
            }
            jobFinished(params, false);
        }, "free-my-tv-" + action).start();
        return true;
    }

    @Override public boolean onStopJob(JobParameters params) {
        return false;
    }

    /** Schedules a job (one pending per action: a new request replaces the old one). */
    static void schedule(Context c, String action, String mode, long delayMs) {
        if (!permitted(action)) return;
        JobScheduler scheduler = c.getSystemService(JobScheduler.class);
        if (scheduler == null) return;
        PersistableBundle extras = new PersistableBundle();
        extras.putString("action", action);
        extras.putString("mode", mode == null ? "" : mode);
        JobInfo.Builder job = new JobInfo.Builder(1000 + Math.abs(action.hashCode() % 1000),
                new ComponentName(c, ModeJob.class)).setExtras(extras);
        if (delayMs > 0) job.setMinimumLatency(delayMs);
        job.setOverrideDeadline(delayMs + 2_000);
        scheduler.schedule(job.build());
    }
}
