package system_setting

import (
	_ "embed"
	"os"

	"github.com/QuantumNous/new-api/setting/config"
)

//go:embed antclaude/about.md
var antClaudeAbout string

//go:embed antclaude/agreement.md
var antClaudeAgreement string

//go:embed antclaude/privacy.md
var antClaudePrivacy string

var DefaultAbout string

type LegalSettings struct {
	UserAgreement string `json:"user_agreement"`
	PrivacyPolicy string `json:"privacy_policy"`
}

var defaultLegalSettings = LegalSettings{
	UserAgreement: "",
	PrivacyPolicy: "",
}

func init() {
	if os.Getenv("NEW_API_SITE_NAME") == "Ant-Claude" {
		DefaultAbout = antClaudeAbout
		defaultLegalSettings.UserAgreement = antClaudeAgreement
		defaultLegalSettings.PrivacyPolicy = antClaudePrivacy
	}
	config.GlobalConfig.Register("legal", &defaultLegalSettings)
}

func GetLegalSettings() *LegalSettings {
	return &defaultLegalSettings
}
