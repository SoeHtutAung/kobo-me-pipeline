# M&E pipeline with API integration and insights generation using LLM
With the demonstration purpose, an R-based M&E data pipeline is created. That automates KoboToolbox submission extraction via the Kobo API V2 with pagination, data validation and processing, LLM-assisted qualitative insights using Gemini (3.5 flash), and reporting through Power BI dashboards. The main objective is to reduce repetitive manual data-processing tasks and create a reproducible workflow for transforming field submissions into analysis-ready datasets and reporting outputs. The project uses `renv` for reproducible R package management. API credentials are stored securely in a `.env` file, which is excluded from the public repository through `.gitignore`.

## Workflow
<img width="800" height="200" alt="Flowchart" src="https://github.com/user-attachments/assets/f662c418-9d35-403e-88ee-ac2174fc02bc" />

## 1. Data extraction from API
Field submissions with KoboCollect are retrieved through the Kobo API V2. 
| `R/01_fetch_kobo.R` | 
| :---- |
• Connects to the KoboToolbox API using credentials stored in environment variables <br/> • Retrieves submissions using API pagination <br/> • Stores a timestamped raw JSON backup <br/> • flattens nested JSON structures and removes unnecessary Kobo metadata fields <br/> • Converts the API response into a tidy data frame <br/> • Applies project-specific cleaning and recoding rules |
The raw API response is retained to provide a reproducible backup of the extracted data.

## 2. Data validation
Before further, the dataset passes through a dedicated data-quality validation stage, using pointblank to perform validation.
| `R/02_data_validation.R` | 
| :---- |
• Conducts data quality checks, such as completeness of key fields, duplicate user identifiers, date validity, missing address/location information <br/> • Includes a column for row-level validation flags |
A validation report is exported as HTML for documentation. <br/> Records with identified data-quality issues are also exported as CSV file to share with field teams for follow up.
<img width="400" height="200" alt="validation_report" src="https://github.com/user-attachments/assets/af5bcef8-3c29-4493-97c2-7c41c1c2699b"/>

## 3. Quantitative data analysis
Demonstration of data analysis on some key M&E indicators and preparation of datasets to pass to Power BI.
| `R/03_analysis.R` | 
| :---- |
• Conducts analysis, such as descriptive analysis to inform rate and proportion <br/> • Produces a fact dataset and dimension tables for use in Power BI |
Processed indicators are exported to include in M&E reports <br/> Datasets for Power BI are kept in OneDrive folder, which separates the data-processing layer from the visualization layer and allows Power BI to consume standardized outputs from the R pipeline. <br/> data/processed/powerbi/ <br/> ├── dataset.csv <br/> ├── buildingtypes.csv <br/> └── damagelevels.csv

## 4. Qualitative data analysis
Additional analysis layer, intended to support analytical interpretation and reporting rather than replace quantitative M&E calculations.
| `R/04_llm_analysis.R` | 
| :---- |
• Prepares building damage data by building type, damage level, number of buildings, percentage of buildings <br/> • Passes the CSV to Gemini with a structured system and user prompt, using API key from Google AI studio. <br/> Produces a concise narrative summary and three key findings in CSV format|
Processed insight report is exported to feed into Power BI. 
Sample system prompt: <br/> _"You are an experienced Monitoring and Evaluation (M&E) expert working in the public health and humanitarian sector. <br/> You will be provided with a CSV table showing building types, damage levels, number of buildings, and percentages. <br/> Return the result as valid JSON with exactly two fields: <br/> 1. 'summary': A concise 1 paragraph narrative highlighting overall pattern of building damage, Compare damage levels across building type, notable findings. <br/> 2. 'findings': A JSON array of 3 bullet-point highlights extracted from the data, including numbers and percentages as applicable."_

## 5. Outputs
The pipeline produces several types of outputs: <br/>
| Output          | Purpose                                  |
| --------------- | ---------------------------------------- |
| Raw JSON        | Reproducible backup of Kobo submissions  |
| Cleaned RDS     | Intermediate analytical dataset          |
| Validation HTML | Data-quality documentation               |
| Flagged CSV     | Records requiring data-quality follow-up |
| Indicator CSVs  | Quantitative M&E indicators              |
| Power BI CSVs   | Dashboard-ready datasets                 |
| LLM RDS/CSV     | Structured qualitative findings          |

And a Power BI dashboard to support decision making <br/> <img width="400" height="375" alt="dashboard_preview" src="https://github.com/user-attachments/assets/1745cf4b-63a9-4162-a5de-357061487a1c" /> <br/> Figure. Dashboard preview


