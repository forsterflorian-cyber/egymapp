import Toybox.WatchUi;
import Toybox.Lang;

(:high_res)
class EGYMNoopConfirmDelegate extends WatchUi.ConfirmationDelegate {
    function initialize() {
        ConfirmationDelegate.initialize();
    }

    function onResponse(response as WatchUi.Confirm) as Boolean {
        return true;
    }
}
