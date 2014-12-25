(function () {
    showCommitId();
    var es = new EventSource("/build/" + getCommitId());
    es.addEventListener("build_log", function(event){
        $(".log-console").append("\n" + event.data);
        $(".log-console").animate(
            { scrollTop:
                $(".log-console")[0].scrollHeight - $(".log-console").height()
            },
            50);
    });

    es.addEventListener("build_finished", function(event){
	document.location.reload();
    });
})();

function showCommitId() {
    $(".commit-id").text(getCommitId());
}
function getCommitId() {
 return document.location.host.split(".")[0];
}

