# helm-charts
All the Gilded Pleb Helm Charts

## Usage

[Helm](https://helm.sh) must be installed to use the charts.  Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

Once Helm has been set up correctly, add the repo as follows:

  helm repo add gildedpleb https://gildedpleb.github.io/helm-charts

If you had already added this repo earlier, run `helm repo update` to retrieve
the latest versions of the packages.  You can then run `helm search repo
gildedpleb` to see the charts.

To install the <chart-name> chart:

    helm install <chart-name> gildedpleb/<chart-name>

To uninstall the chart:

    helm delete <chart-name>