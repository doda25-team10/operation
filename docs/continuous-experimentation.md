# Experiment: User Engagement Improvement

# Overview
This experiment will test if the new Experimental UI design improves user engagement compared to the existing Stable version.

# Deploying the Experiment
You can view both conditions of the experiment yourself. With the deployment of the app, two frontend versions are deployed:
1.  **Stable Version**: The current base version of the application.
2.  **Experimental Version**: The new version with the proposed UI changes.

To view the two versions, access the application (e.g., via `frontend.local` or your specific deployment URL). You may need to refresh or use specific headers/cookies to toggle between the stable and experimental versions depending on the routing configuration.

# Changes
The experiment compares two UI versions:
-   **Stable UI**: The standard interface currently in production.
![Stable UI](./images/ui_stable.png)
-   **Experimental UI**: A modified interface designed to increase user interaction.
![Experimental UI](./images/ui_experimental.jpeg)

# Hypothesis
The experimental UI will improve user engagement compared to the stable version, specifically:
*   Increasing interaction rate by at least 15%
*   Decreasing abandonment rate by at least 15%

# Relevant Metrics
To analyze changes in user engagement, we will track:
*   `total_predictions`: The total number of predictions (spam + ham).
*   `abandonment_rate`: The percentage of sessions where users leave without completing a primary action.

If the Experimental UI shows a statistically significant improvement in these metrics compared to the Stable UI, the hypothesis will be supported.

# Decision Process
We will deploy the Stable version to one user group and the Experimental version to another. We will collect metrics for `total_predictions` and `abandonment_rate` for both groups. Using a Grafana dashboard, we will visualize the time-series data for both versions. We will compare the performance of the Experimental UI against the Stable baseline to determine if the 15% improvement targets are met.

# Grafana Results
Below are the results of the experiment, indicating that the experimental UI improves user engagement compared to the stable version.
![Grafana Results](./images/grafana_results.jpeg)

# Limitations
As this is an initial experiment, data may be mocked or limited to a testing environment, which may not perfectly reflect real-world usage patterns.