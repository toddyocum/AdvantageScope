import Log from "../../lib/log/Log";
import WorkerManager from "../../lib/WorkerManager";
import { HistorialDataSource, HistorialDataSourceStatus } from "./HistoricalDataSource";

export default class RLOGFileSource extends HistorialDataSource {
  handleMainMessage(data: any) {
    if (this.status != HistorialDataSourceStatus.Reading) return;
    this.setStatus(HistorialDataSourceStatus.Decoding);

    WorkerManager.request("../bundles/hub$rlogworker.js", data)
      .then((log: Log) => {
        if (this.status == HistorialDataSourceStatus.Error || this.status == HistorialDataSourceStatus.Stopped) return;
        this.setStatus(HistorialDataSourceStatus.Ready);
        if (this.outputCallback != null) this.outputCallback(log);
      })
      .catch(() => {
        if (this.status == HistorialDataSourceStatus.Stopped) return;
        this.setStatus(HistorialDataSourceStatus.Error);
      });
  }
}
