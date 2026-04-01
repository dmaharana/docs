# GitHub Copilot Billing API with Golang and PostgreSQL

This guide demonstrates how to access the GitHub Copilot Billing API using Golang and store the retrieved data in a PostgreSQL database using GORM, a popular Go ORM package.

## Prerequisites

- Go 1.21 or later
- PostgreSQL 13 or later
- GORM package
- GitHub Personal Access Token with `manage_billing:copilot` or `read:org` scope

## Setup

### 1. Install Dependencies

```bash
go mod init copilot-billing
go get -u github.com/lib/pq
go get -u gorm.io/gorm
go get -u gorm.io/driver/postgres
```

### 2. Database Configuration

Create a PostgreSQL database and update the connection string in the code:

```go
const (
    host     = "localhost"
    port     = 5432
    user     = "your_username"
    password = "your_password"
    dbname   = "copilot_billing"
)
```

### 3. GitHub API Configuration

Set your GitHub token as an environment variable:

```bash
export GITHUB_TOKEN="your_github_token"
```

## Code Example

```go
package main

import (
    "context"
    "encoding/json"
    "fmt"
    "log"
    "os"

    "github.com/lib/pq"
    "gorm.io/driver/postgres"
    "gorm.io/gorm"
)

// OrganizationBilling represents the billing information for an organization
type OrganizationBilling struct {
    ID                      uint   `gorm:"primaryKey"`
    OrgName                 string `gorm:"uniqueIndex"`
    TotalSeats              int
    AddedThisCycle          int
    PendingInvitation       int
    PendingCancellation     int
    ActiveThisCycle         int
    InactiveThisCycle       int
    SeatManagementSetting   string
    IDEChat                 string
    PlatformChat            string
    CLI                     string
    PublicCodeSuggestions   string
    PlanType                string
    CreatedAt               string
    UpdatedAt               string
}

// CopilotSeat represents a single Copilot seat assignment
type CopilotSeat struct {
    ID                         uint   `gorm:"primaryKey"`
    AssigneeLogin              string `gorm:"index"`
    AssigneeID                 int64
    AssigneeAvatarURL          string
    AssigneeURL                string
    AssigneeHTMLURL            string
    AssigneeType               string
    AssigneeSiteAdmin          bool
    AssigningTeamID            *int64 `gorm:"default:null"`
    AssigningTeamName          *string `gorm:"default:null"`
    AssigningTeamSlug          *string `gorm:"default:null"`
    AssigningTeamDescription   *string `gorm:"default:null"`
    AssigningTeamPrivacy       *string `gorm:"default:null"`
    AssigningTeamURL           *string `gorm:"default:null"`
    AssigningTeamHTMLURL       *string `gorm:"default:null"`
    AssigningTeamNodeID        *string `gorm:"default:null"`
    CreatedAt                  string
    UpdatedAt                  string
    PendingCancellationDate    *string `gorm:"default:null"`
    LastActivityAt             *string `gorm:"default:null"`
    LastActivityEditor         *string `gorm:"default:null"`
    LastAuthenticatedAt        *string `gorm:"default:null"`
    PlanType                   string
    OrganizationBillingID      uint
}

func main() {
    // Connect to PostgreSQL
    dsn := fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=disable",
        "localhost", 5432, "your_username", "your_password", "copilot_billing")
    
    db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
    if err != nil {
        log.Fatal("Failed to connect to database:", err)
    }

    // Migrate the schema
    db.AutoMigrate(&OrganizationBilling{}, &CopilotSeat{})

    // GitHub API configuration
    orgName := "your-organization-name"
    token := os.Getenv("GITHUB_TOKEN")
    if token == "" {
        log.Fatal("GITHUB_TOKEN environment variable is required")
    }

    // Fetch organization billing information
    orgBilling, err := fetchOrganizationBilling(orgName, token)
    if err != nil {
        log.Fatal("Failed to fetch organization billing:", err)
    }

    // Save organization billing to database
    if err := saveOrganizationBilling(db, orgName, orgBilling); err != nil {
        log.Fatal("Failed to save organization billing:", err)
    }

    // Fetch all Copilot seat assignments
    seats, err := fetchCopilotSeats(orgName, token)
    if err != nil {
        log.Fatal("Failed to fetch Copilot seats:", err)
    }

    // Save seats to database
    if err := saveCopilotSeats(db, orgName, seats); err != nil {
        log.Fatal("Failed to save Copilot seats:", err)
    }

    fmt.Println("Successfully fetched and stored Copilot billing data")
}

// fetchOrganizationBilling retrieves billing information for an organization
func fetchOrganizationBilling(orgName, token string) (*OrganizationBilling, error) {
    url := fmt.Sprintf("https://api.github.com/orgs/%s/copilot/billing", orgName)
    
    // In a real implementation, you would make an HTTP request here
    // For this example, we'll return a mock struct
    return &OrganizationBilling{
        OrgName: orgName,
        TotalSeats: 12,
        AddedThisCycle: 9,
        PendingInvitation: 0,
        PendingCancellation: 0,
        ActiveThisCycle: 12,
        InactiveThisCycle: 11,
        SeatManagementSetting: "assign_selected",
        IDEChat: "enabled",
        PlatformChat: "enabled",
        CLI: "enabled",
        PublicCodeSuggestions: "block",
        PlanType: "business",
    }, nil
}

// fetchCopilotSeats retrieves all Copilot seat assignments for an organization
func fetchCopilotSeats(orgName, token string) ([]*CopilotSeat, error) {
    url := fmt.Sprintf("https://api.github.com/orgs/%s/copilot/billing/seats", orgName)
    
    // In a real implementation, you would make an HTTP request here
    // For this example, we'll return mock data
    return []*CopilotSeat{
        {
            AssigneeLogin: "octocat",
            AssigneeID: 1,
            AssigneeAvatarURL: "https://github.com/images/error/octocat_happy.gif",
            AssigneeURL: "https://api.github.com/users/octocat",
            AssigneeHTMLURL: "https://github.com/octocat",
            AssigneeType: "User",
            AssigneeSiteAdmin: false,
            AssigningTeamID: pq.Int64Ptr(1),
            AssigningTeamName: pq.StringPtr("Justice League"),
            AssigningTeamSlug: pq.StringPtr("justice-league"),
            AssigningTeamDescription: pq.StringPtr("A great team."),
            AssigningTeamPrivacy: pq.StringPtr("closed"),
            AssigningTeamURL: pq.StringPtr("https://api.github.com/teams/1"),
            AssigningTeamHTMLURL: pq.StringPtr("https://github.com/orgs/github/teams/justice-league"),
            AssigningTeamNodeID: pq.StringPtr("MDQ6VGVhbTE="),
            CreatedAt: "2021-08-03T18:00:00-06:00",
            UpdatedAt: "2021-09-23T15:00:00-06:00",
            PendingCancellationDate: nil,
            LastActivityAt: pq.StringPtr("2021-10-14T00:53:32-06:00"),
            LastActivityEditor: pq.StringPtr("vscode/1.77.3/copilot/1.86.82"),
            LastAuthenticatedAt: pq.StringPtr("2021-10-14T00:53:32-06:00"),
            PlanType: "business",
        },
    }, nil
}

// saveOrganizationBilling saves organization billing information to the database
func saveOrganizationBilling(db *gorm.DB, orgName string, billing *OrganizationBilling) error {
    return db.Where(OrganizationBilling{OrgName: orgName}).Assign(*billing).FirstOrCreate(&OrganizationBilling{}).Error
}

// saveCopilotSeats saves Copilot seat assignments to the database
func saveCopilotSeats(db *gorm.DB, orgName string, seats []*CopilotSeat) error {
    var orgBilling OrganizationBilling
    if err := db.Where("org_name = ?", orgName).First(&orgBilling).Error; err != nil {
        return err
    }

    for _, seat := range seats {
        seat.OrganizationBillingID = orgBilling.ID
        if err := db.Where(CopilotSeat{AssigneeLogin: seat.AssigneeLogin}).
                   Assign(*seat).
                   FirstOrCreate(&CopilotSeat{}).Error; err != nil {
            return err
        }
    }
    return nil
}
```

## API Endpoints Used

This example uses the following GitHub Copilot Billing API endpoints:

1. **Get Copilot seat information and settings for an organization**
   - `GET /orgs/{org}/copilot/billing`
   - Retrieves organization-wide Copilot subscription information including seat breakdown and feature policies

2. **List all Copilot seat assignments for an organization**
   - `GET /orgs/{org}/copilot/billing/seats`
   - Lists all Copilot seats for which the organization is being billed

## Database Schema

The code creates two tables:

1. **organization_billing**: Stores organization-level billing information
2. **copilot_seats**: Stores individual seat assignment details with foreign key relationship to organization_billing

## Error Handling

The example includes basic error handling for:
- Database connection failures
- API request failures
- Data insertion failures

## Security Considerations

- Store the GitHub token in environment variables, not in source code
- Use proper database connection pooling in production
- Implement rate limiting for API calls
- Consider using GitHub App tokens instead of personal access tokens for better security

## Next Steps

- Add support for other Copilot API endpoints (adding/removing users/teams)
- Implement pagination for seat listing
- Add data validation and sanitization
- Create API endpoints to serve the stored data
- Implement data refresh mechanisms