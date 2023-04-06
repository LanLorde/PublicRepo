﻿<#
.SYNOPSIS
  <Overview of script>
.DESCRIPTION
  <Brief description of script>
.PARAMETER <Parameter_Name>
    <Brief description of parameter input required. Repeat this attribute if required>
.INPUTS
  <Inputs if any, otherwise state None>
.OUTPUTS
  <Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>
.NOTES
  Version:        1.0
  Author:         <Name>
  Creation Date:  <Date>
  Purpose/Change: Initial script development
  
.EXAMPLE
  <Example goes here. Repeat this attribute for more than one example>
#>



$i = 0
$Users = Get-MsolUser -All -EnabledFilter EnabledOnly | Where-Object { $_.isLicensed -eq "True" }
$Data = ForEach ($User in $Users) {
    
    $mbx = Get-Mailbox $User.UserPrincipalName | Select-Object DisplayName, PrimarySMTPAddress -ErrorAction SilentlyContinue
    $License = switch ($User.Licenses.AccountSku.SKuPartNumber) {
        AAD_BASIC { 'Azure Active Directory Basic' }
        AAD_BASIC_AAD_BASIC { 'Azure AD Basic - Azure Active Directory Basic' }
        AAD_BASIC_EDU { 'Azure Active Directory Basic for EDU' }
        AAD_EDU { 'Azure Active Directory for Education' }
        AAD_PREMIUM { 'Azure Active Directory Premium P1' }
        AAD_PREMIUM_AAD_PREMIUM { 'Azure AD Premium P1 - Azure AD Premium P1' }
        AAD_PREMIUM_MFA_PREMIUM { 'Azure AD Premium P1 - Azure Multi-Factor Authentication' }
        AAD_PREMIUM_P2 { 'Azure Active Directory Premium P2' }
        AAD_PREMIUM_P2_AAD_PREMIUM { 'Azure AD Premium P2 - Azure AD Premium P1' }
        AAD_PREMIUM_P2_AAD_PREMIUM_P2 { 'Azure AD Premium P2 - Azure AD Premium P2' }
        AAD_PREMIUM_P2_ADALLOM_S_DISCOVERY { 'Azure AD Premium P2 - Cloud App Security Discovery' }
        AAD_PREMIUM_P2_MFA_PREMIUM { 'Azure AD Premium P2 - Azure Multi-Factor Authentication' }
        AAD_SMB { 'Azure Active Directory' }
        ADALLOM_S_DISCOVERY { 'Cloud App Security Discovery' }
        ADALLOM_S_O365 { 'Office 365 Advanced Security Management' }
        ADALLOM_S_STANDALONE { 'Microsoft Cloud App Security' }
        ADALLOM_STANDALONE { 'Microsoft Cloud App Security' }
        ADV_COMMS { 'Advanced Communications add-on for Microsoft Teams' }
        ATA { 'Azure Advanced Threat Protection' }
        ATP_ENTERPRISE { 'Office 365 Advanced Threat Protection (Plan 1)' }
        ATP_ENTERPRISE_FACULTY { 'Exchange Online Advanced Threat Protection' }
        AX_ENTERPRISE_USER { 'Microsoft Dynamics AX Enterprise' }
        AX_SELF-SERVE_USER { 'Microsoft Dynamics AX Self-Serve' }
        AX7_USER_TRIAL { 'Microsoft Dynamics AX7 User Trial' }
        BI_AZURE_P0 { 'Power BI (free)' }
        BI_AZURE_P1 { 'Microsoft Power BI Reporting And Analytics Plan 1' }
        BI_AZURE_P2 { 'Power BI Pro' }
        BPOS_S_TODO_1 { 'To-do (Plan 1)' }
        BPOS_S_TODO_2 { 'To-do (Plan 2)' }
        BPOS_S_TODO_3 { 'To-do (Plan 3)' }
        BPOS_S_TODO_FIRSTLINE { 'To-do (Firstline)' }
        BUSINESS_VOICE_MED2 { 'Microsoft 365 Business Voice' }
        CCIBOTS_PRIVPREV_VIRAL { 'Power Virtual Agents Viral Trial' }
        CCIBOTS_PRIVPREV_VIRAL_CCIBOTS_PRIVPREV_VIRAL { 'Dynamics Bots Trial' }
        CCIBOTS_PRIVPREV_VIRAL_DYN365_CDS_CCI_BOTS { 'Dynamics Bots Trial - Common Data Service' }
        CCIBOTS_PRIVPREV_VIRAL_FLOW_CCI_BOTS { 'Dynamics Bots Trial - Microsoft Flow' }
        CDS_DB_CAPACITY { 'CDS DB Capacity' }
        COMMUNICATIONS_COMPLIANCE { 'Microsoft Communications Compliance' }
        COMMUNICATIONS_DLP { 'Microsoft Communications Dlp' }
        CRM_HYBRIDCONNECTOR { 'CRM Hybrid Connector' }
        CRMENTERPRISE { 'Microsoft Dynamics CRM Online Enterprise' }
        CRMIUR { 'CRM for Partners' }
        CRMPLAN2 { 'Microsoft Dynamics CRM Online Basic' }
        CRMPLAN2_CRMPLAN2 { 'Microsoft Dynamics CRM Online Basic' }
        CRMPLAN2_FLOW_DYN_APPS { 'MS Dynamics CRM Online Basic - Flow for Dynamics 365' }
        CRMPLAN2_POWERAPPS_DYN_APPS { 'MS Dynamics CRM Online Basic - PowerApps for Office 365' }
        CRMSTANDARD { 'Microsoft Dynamics CRM Online' }
        CRMSTANDARD_CRMSTANDARD { 'Microsoft Dynamics CRM Online' }
        CRMSTANDARD_FLOW_DYN_APPS { 'MS Dynamics CRM Online - Flow for Dynamics 365' }
        CRMSTANDARD_GCC { 'Microsoft Dynamics CRM Online Government Professional' }
        CRMSTANDARD_MDM_SALES_COLLABORATION { 'MS Dynamics CRM Online - MS Dynamics Marketing Sales Collaboration' }
        CRMSTANDARD_NBPROFESSIONALFORCRM { 'MS Dynamics CRM Online - MS Social Engagement Professional' }
        CRMSTANDARD_POWERAPPS_DYN_APPS { 'MS Dynamics CRM Online - PowerApps for Office 365' }
        CRMSTORAGE { 'Microsoft Dynamics CRM Storage' }
        CRMTESTINSTANCE { 'Microsoft Dynamics CRM Test Instance' }
        CUSTOMER_KEY { 'Microsoft Customer Key' }
        DATA_INVESTIGATIONS { 'Microsoft Data Investigations' }
        DDYN365_CDS_DYN_P2 { 'Common Data Service' }
        Deskless { 'Microsoft Staffhub' }
        DESKLESSPACK { 'Office 365 F1' }
        DESKLESSPACK_BPOS_S_TODO_FIRSTLINE { 'O365 F1 - To-do (Firstline)' }
        DESKLESSPACK_DESKLESS { 'O365 F1 - Microsoft StaffHub' }
        DESKLESSPACK_DYN365_CDS_O365_F1 { 'O365 F1 - Common Data Service' }
        DESKLESSPACK_EXCHANGE_S_DESKLESS { 'O365 F1 - Exchange Online Kiosk' }
        DESKLESSPACK_FLOW_O365_S1 { 'O365 F1 - Flow for Office 365 K1' }
        DESKLESSPACK_FORMS_PLAN_K { 'O365 F1 - Microsoft Forms (Plan F1)' }
        DESKLESSPACK_GOV { 'Office 365 F1 for Government' }
        DESKLESSPACK_KAIZALA_O365_P1 { 'O365 F1 - Microsoft Kaizala Pro' }
        DESKLESSPACK_MCOIMP { 'O365 F1 - Skype for Business Online (P1)' }
        DESKLESSPACK_OFFICEMOBILE_SUBSCRIPTION { 'O365 F1 - Mobile Apps for Office 365' }
        DESKLESSPACK_POWERAPPS_O365_S1 { 'O365 F1 - Powerapps for Office 365 K1' }
        DESKLESSPACK_PROJECTWORKMANAGEMENT { 'O365 F1 - Microsoft Planner' }
        DESKLESSPACK_SHAREPOINTDESKLESS { 'O365 F1 - SharePoint Online Kiosk' }
        DESKLESSPACK_SHAREPOINTWAC { 'O365 F1 - Office for web' }
        DESKLESSPACK_STREAM_O365_K { 'O365 F1 - Microsoft Stream for O365 K SKU' }
        DESKLESSPACK_SWAY { 'O365 F1 - Sway' }
        DESKLESSPACK_TEAMS1 { 'O365 F1 - Microsoft Teams' }
        DESKLESSPACK_WHITEBOARD_FIRSTLINE1 { 'O365 F1 - Whiteboard (Firstline)' }
        DESKLESSPACK_YAMMER { 'Office 365 F1 with Yammer' }
        DESKLESSPACK_YAMMER_ENTERPRISE { 'O365 F1 - Yammer Enterprise' }
        DESKLESSWOFFPACK { 'Office 365 Kiosk P2' }
        DESKLESSWOFFPACK_GOV { 'Office 365 Kiosk P2 for Government' }
        DEVELOPERPACK { 'Office 365 E3 Developer' }
        DEVELOPERPACK_EXCHANGE_S_ENTERPRISE { 'O365 E3 Developer - Exchange Online (P2)' }
        DEVELOPERPACK_FLOW_O365_P2 { 'O365 E3 Developer - Flow for Office 365' }
        DEVELOPERPACK_FORMS_PLAN_E5 { 'O365 E3 Developer - Microsft Forms (Plan E5)' }
        DEVELOPERPACK_GOV { 'Office 365 Developer for Government' }
        DEVELOPERPACK_MCOSTANDARD { 'O365 E3 Developer - Skype for Business Online (P2)' }
        DEVELOPERPACK_OFFICESUBSCRIPTION { 'O365 E3 Developer - Office 365 ProPlus' }
        DEVELOPERPACK_POWERAPPS_O365_P2 { 'O365 E3 Developer - PowerApps for Office 365' }
        DEVELOPERPACK_PROJECTWORKMANAGEMENT { 'O365 E3 Developer - Microsoft Planner' }
        DEVELOPERPACK_SHAREPOINT_S_DEVELOPER { 'O365 E3 Developer - SharePoint (P2)' }
        DEVELOPERPACK_SHAREPOINTWAC_DEVELOPER { 'O365 E3 Developer - Office for web' }
        DEVELOPERPACK_STREAM_O365_E5 { 'O365 E3 Developer - Stream for Office 365' }
        DEVELOPERPACK_SWAY { 'O365 E3 Developer - Sway' }
        DEVELOPERPACK_TEAMS1 { 'O365 E3 Developer - Microsoft Teams' }
        DMENTERPRISE { 'Microsoft Dynamics Marketing Online Enterprise' }
        DYN365_AI_SERVICE_INSIGHTS_DYN365_AI_SERVICE_INSIGHTS { 'Dynamics 365 Customer Service Insights' }
        DYN365_BUSINESS_MARKETING { 'Dynamics 365 for Marketing' }
        DYN365_CDS_DYN_APPS { 'Common Data Service' }
        DYN365_CDS_PROJECT { 'Common Data Service for Project' }
        DYN365_CDS_VIRAL { 'Common Data Service' }
        DYN365_ENTERPRISE_CUSTOMER_SERVICE { 'Dynamics 365 for Customer Service Enterprise Edition' }
        DYN365_ENTERPRISE_P1 { 'Dynamics 365 Customer Engagement Plan' }
        DYN365_ENTERPRISE_P1_IW { 'Dynamics 365 P1 Trial for Information Workers' }
        DYN365_ENTERPRISE_P1_IW_DYN365_ENTERPRISE_P1_IW { 'Dynamics 365 P1 Trial for Information Workers' }
        DYN365_ENTERPRISE_PLAN1 { 'Dynamics 365 Customer Engagement Plan Enterprise Edition' }
        DYN365_ENTERPRISE_PLAN1_DYN365_ENTERPRISE_P1 { 'D365 Customer Engagement Plan Ent Edition - Dynamics 365 Customer Engagement Plan' }
        DYN365_ENTERPRISE_PLAN1_FLOW_DYN_P2 { 'D365 Customer Engagement Plan Ent Edition - Flow for Dynamics 365' }
        DYN365_ENTERPRISE_PLAN1_NBENTERPRISE { 'D365 Customer Engagement Plan Ent Edition - MS Social Engagement - Service Discontinuation' }
        DYN365_ENTERPRISE_PLAN1_POWERAPPS_DYN_P2 { 'D365 Customer Engagement Plan Ent Edition - Powerapps for Dynamics 365' }
        DYN365_ENTERPRISE_PLAN1_PROJECT_CLIENT_SUBSCRIPTION { 'D365 Customer Engagement Plan Ent Edition - Project Online Desktop Client' }
        DYN365_ENTERPRISE_PLAN1_SHAREPOINT_PROJECT { 'D365 Customer Engagement Plan Ent Edition - Project Online Service' }
        DYN365_ENTERPRISE_PLAN1_SHAREPOINTENTERPRISE { 'D365 Customer Engagement Plan Ent Edition - SharePoint (P2)' }
        DYN365_ENTERPRISE_PLAN1_SHAREPOINTWAC { 'D365 Customer Engagement Plan Ent Edition - Office for web' }
        DYN365_ENTERPRISE_SALES { 'Dynamics 365 for Sales Enterprise Edition' }
        DYN365_ENTERPRISE_SALES_CUSTOMERSERVICE { 'Dynamics 365 for Sales And Customer Service Enterprise Edition' }
        DYN365_ENTERPRISE_SALES_DYN365_ENTERPRISE_SALES { 'D365 for Sales Enterprise Edition - Dynamics 365 for Sales Enterprise Edition' }
        DYN365_ENTERPRISE_SALES_FLOW_DYN_APPS { 'D365 for Sales Enterprise Edition - Flow for Dynamics 365' }
        DYN365_ENTERPRISE_SALES_NBENTERPRISE { 'D365 for Sales Enterprise Edition - MS Social Engagement - Service Discontinuation' }
        DYN365_ENTERPRISE_SALES_POWERAPPS_DYN_APPS { 'D365 for Sales Enterprise Edition - PowerApps for Office 365' }
        DYN365_ENTERPRISE_SALES_PROJECT_ESSENTIALS { 'D365 for Sales Enterprise Edition - Project Online Essential' }
        DYN365_ENTERPRISE_SALES_SHAREPOINTENTERPRISE { 'D365 for Sales Enterprise Edition - SharePoint (P2)' }
        DYN365_ENTERPRISE_SALES_SHAREPOINTWAC { 'D365 for Sales Enterprise Edition - Office for web' }
        DYN365_Enterprise_Talent_Attract_TeamMember { 'Dynamics 365 for Talent - Attract Experience Team Member' }
        DYN365_Enterprise_Talent_Onboard_TeamMember { 'Dynamics 365 for Talent - Onboard Experience' }
        DYN365_ENTERPRISE_TEAM_MEMBERS { 'Dynamics 365 for Team Members Enterprise Edition' }
        DYN365_ENTERPRISE_TEAM_MEMBERS_DYN365_ENTERPRISE_TALENT_ATTRACT_TEAMMEMBER { 'D365 for Team Members Ent Edition - D365 for Talent - Attract Experience Team Member' }
        DYN365_ENTERPRISE_TEAM_MEMBERS_DYN365_ENTERPRISE_TALENT_ONBOARD_TEAMMEMBER { 'D365 for Team Members Ent Edition - D365 for Talent - Onboard Experience' }
        DYN365_ENTERPRISE_TEAM_MEMBERS_DYN365_ENTERPRISE_TEAM_MEMBERS { 'Dynamics 365 for Team Members Enterprise Edition' }
        DYN365_ENTERPRISE_TEAM_MEMBERS_DYNAMICS_365_FOR_OPERATIONS_TEAM_MEMBERS { 'D365 for Team Members Ent Edition - Dynamics 365 for Operations Member' }
        DYN365_ENTERPRISE_TEAM_MEMBERS_DYNAMICS_365_FOR_RETAIL_TEAM_MEMBERS { 'D365 for Team Members Ent Edition - Dynamics 365 for Retail Member' }
        DYN365_ENTERPRISE_TEAM_MEMBERS_DYNAMICS_365_FOR_TALENT_TEAM_MEMBERS { 'D365 for Team Members Ent Edition - Dynamics 365 for Talent Member' }
        DYN365_ENTERPRISE_TEAM_MEMBERS_FLOW_DYN_TEAM { 'D365 for Team Members Ent Edition - Flow for Office 365' }
        DYN365_ENTERPRISE_TEAM_MEMBERS_POWERAPPS_DYN_TEAM { 'D365 for Team Members Ent Edition - PowerApps for Office 365' }
        DYN365_ENTERPRISE_TEAM_MEMBERS_PROJECT_ESSENTIALS { 'D365 for Team Members Ent Edition - Project Online Essential' }
        DYN365_ENTERPRISE_TEAM_MEMBERS_SHAREPOINTENTERPRISE { 'D365 for Team Members Ent Edition - SharePoint (P2)' }
        DYN365_ENTERPRISE_TEAM_MEMBERS_SHAREPOINTWAC { 'D365 for Team Members Ent Edition - Office for web' }
        DYN365_FINANCE { 'Dynamics 365 Finance' }
        DYN365_FINANCIALS_BUSINESS { 'Dynamics 365 for Financials' }
        DYN365_FINANCIALS_BUSINESS_SKU { 'Dynamics 365 for Financials Business Edition' }
        DYN365_FINANCIALS_BUSINESS_SKU_DYN365_FINANCIALS_BUSINESS { 'Dynamics 365 for Financials Business Edition' }
        DYN365_FINANCIALS_BUSINESS_SKU_FLOW_DYN_APPS { 'D365 for Financials Business Edition - Flow for Dynamics 365' }
        DYN365_FINANCIALS_BUSINESS_SKU_POWERAPPS_DYN_APPS { 'D365 for Financials Business Edition - PowerApps for Office 365' }
        DYN365_FINANCIALS_TEAM_MEMBERS_SKU { 'Dynamics 365 for Team Members Business Edition' }
        DYN365_RETAIL_TRIAL { 'Dynamics 365 for Retail Trial' }
        DYN365_SCM { 'Dynamics 365 for Supply Chain Management' }
        DYN365_SCM_ATTACH { 'Dynamics 365 Supply Chain Management Attach to Qualifying Dynamics 365 Base Offer' }
        DYN365_TALENT_ENTERPRISE { 'Dynamics 365 for Talent' }
        DYN365_TEAM_MEMBERS { 'Dynamics 365 Team Members' }
        Dyn365_Operations_Activity { 'Dyn365 für Operations Activity Enterprise Edition' }
        Dynamics_365_for_Operations { 'Dynamics 365 Unf Ops Plan Ent Edition' }
        Dynamics_365_for_Retail { 'Dynamics 365 for Retail' }
        Dynamics_365_for_Retail_Team_members { 'Dynamics 365 for Retail Team Members' }
        Dynamics_365_for_Talent_Team_members { 'Dynamics 365 for Talent Team Members' }
        Dynamics_365_Onboarding_Free_PLAN { 'Dynamics 365 for Talent: Onboard' }
        Dynamics_365_Onboarding_SKU { 'Dynamics 365 for Talent: Onboard' }
        DYNAMICS_365_ONBOARDING_SKU_DYN365_CDS_DYN_APPS { 'Dynamics 365 for Talent: Onboard - Common Data Service' }
        DYNAMICS_365_ONBOARDING_SKU_DYNAMICS_365_ONBOARDING_FREE_PLAN { 'Dynamics 365 for Talent: Onboard' }
        DYNAMICS_365_ONBOARDING_SKU_DYNAMICS_365_TALENT_ONBOARD { 'Dynamics 365 for Talent: Onboard - Dynamics 365 for Talent: Onboard' }
        Dynamics_365_for_Operations_Sandbox_Tier2_SKU { 'Dynamics 365 Operations – Sandbox Tier 2:Standard Acceptance Testing' }
        ECAL_SERVICES { 'ECAL Services (EOA, EOP, DLP)' }
        EducationAnalyticsP1 { 'Education Analytics' }
        EDUPACK_FACULTY { 'Office 365 Education E3 for Faculty' }
        EDUPACK_STUDENT { 'Office 365 Education for Students' }
        EMS { 'Enterprise Mobility + Security E3' }
        EMS_AAD_PREMIUM { 'Ent Mobility + Security E3 - Azure AD Premium P1' }
        EMS_ADALLOM_S_DISCOVERY { 'Ent Mobility + Security E3 - Cloud App Security Discovery' }
        EMS_EDU_STUUSBNFT { 'Enterprise Mobility + Security A3' }
        EMS_INTUNE_A { 'Ent Mobility + Security E3 - Microsoft Intune' }
        EMS_MFA_PREMIUM { 'Ent Mobility + Security E3 - Azure Multi-Factor Authentication' }
        EMS_RMS_S_ENTERPRISE { 'Ent Mobility + Security E3 - Azure Rights Management' }
        EMS_RMS_S_PREMIUM { 'Ent Mobility + Security E3 - Azure Information Protection P1' }
        EMSPREMIUM { 'Enterprise Mobility + Security E5' }
        EMSPREMIUM_AAD_PREMIUM { 'Ent Mobility + Security E5 - Azure AD Premium P1' }
        EMSPREMIUM_AAD_PREMIUM_P2 { 'Ent Mobility + Security E5 - Azure AD Premium P2' }
        EMSPREMIUM_ADALLOM_S_STANDALONE { 'Ent Mobility + Security E5 - Microsoft Cloud App Security' }
        EMSPREMIUM_ATA { 'Ent Mobility + Security E5 - Azure Advanced Threat Protection' }
        EMSPREMIUM_INTUNE_A { 'Ent Mobility + Security E5 - Microsoft Intune' }
        EMSPREMIUM_MFA_PREMIUM { 'Ent Mobility + Security E5 - Azure Multi-Factor Authentication' }
        EMSPREMIUM_RMS_S_ENTERPRISE { 'Ent Mobility + Security E5 - Azure Rights Management' }
        EMSPREMIUM_RMS_S_PREMIUM { 'Ent Mobility + Security E5 - Azure Information Protection P1' }
        EMSPREMIUM_RMS_S_PREMIUM2 { 'Ent Mobility + Security E5 - Azure Information Protection P2' }
        ENTERPRISEPACK { 'Office 365 E3' }
        ENTERPRISEPACK_BPOS_S_TODO_2 { 'O365 E3 - To-do (P2)' }
        ENTERPRISEPACK_DESKLESS { 'O365 E3 - Microsoft StaffHub' }
        ENTERPRISEPACK_EXCHANGE_S_ENTERPRISE { 'O365 E3 - Exchange Online (P2)' }
        ENTERPRISEPACK_FACULTY { 'Office 365 Education E3 for Faculty' }
        ENTERPRISEPACK_FLOW_O365_P2 { 'O365 E3 - Flow for Office 365' }
        ENTERPRISEPACK_FORMS_PLAN_E3 { 'O365 E3 - Microsft Forms (Plan E3)' }
        ENTERPRISEPACK_GOV { 'Office 365 Enterprise E3 for Government' }
        ENTERPRISEPACK_KAIZALA_O365_P3 { 'O365 E3 - Microsoft Kaizala Pro' }
        ENTERPRISEPACK_MCOSTANDARD { 'O365 E3 - Skype for Business Online (P2)' }
        ENTERPRISEPACK_MIP_S_CLP1 { 'O365 E3 - Information Protection for Office 365 - Standard' }
        ENTERPRISEPACK_MYANALYTICS_P2 { 'O365 E3 - Insights by MyAnalytics' }
        ENTERPRISEPACK_OFFICESUBSCRIPTION { 'O365 E3 - Office 365 ProPlus' }
        ENTERPRISEPACK_POWERAPPS_O365_P2 { 'O365 E3 - PowerApps for Office 365' }
        ENTERPRISEPACK_PROJECTWORKMANAGEMENT { 'O365 E3 - Microsoft Planner' }
        ENTERPRISEPACK_RMS_S_ENTERPRISE { 'O365 E3 - Azure Rights Management' }
        ENTERPRISEPACK_SHAREPOINTENTERPRISE { 'O365 E3 - SharePoint (P2)' }
        ENTERPRISEPACK_SHAREPOINTWAC { 'O365 E3 - Office for web' }
        ENTERPRISEPACK_STREAM_O365_E3 { 'O365 E3 - Stream for Office 365' }
        ENTERPRISEPACK_STUDENT { 'Office 365 Education E3 for Students' }
        ENTERPRISEPACK_SWAY { 'O365 E3 - Sway' }
        ENTERPRISEPACK_TEAMS1 { 'O365 E3 - Microsoft Teams' }
        ENTERPRISEPACK_USGOV_DOD { 'Office 365 E3 US GOV DoD' }
        ENTERPRISEPACK_USGOV_GCCHIGH { 'Office 365 E3 US GOV GCC High' }
        ENTERPRISEPACK_WHITEBOARD_PLAN2 { 'O365 E3 - Whiteboard (P2)' }
        ENTERPRISEPACK_YAMMER_ENTERPRISE { 'O365 E3 - Yammer Enterprise' }
        ENTERPRISEPACKLRG { 'Office 365 (Plan E3)' }
        ENTERPRISEPACKPLUS_FACULTY { 'Office 365 A3 for faculty' }
        ENTERPRISEPACKWITHOUTPROPLUS { 'Office 365 Enterprise E3 without ProPlus Add-on' }
        ENTERPRISEPACKWSCAL { 'Office 365 Enterprise E4' }
        ENTERPRISEPREMIUM { 'Office 365 E5' }
        ENTERPRISEPREMIUM_ADALLOM_S_O365 { 'O365 E5 - Office 365 Advanced Security Management' }
        ENTERPRISEPREMIUM_ATP_ENTERPRISE { 'O365 E5 - Office 365 Advanced Threat Protection (P1)' }
        ENTERPRISEPREMIUM_BI_AZURE_P2 { 'O365 E5 - Power BI Pro' }
        ENTERPRISEPREMIUM_BPOS_S_TODO_3 { 'O365 E5 - To-do (P3)' }
        ENTERPRISEPREMIUM_COMMUNICATIONS_COMPLIANCE { 'O365 E5 - Microsoft Communications Compliance' }
        ENTERPRISEPREMIUM_COMMUNICATIONS_DLP { 'O365 E5 - Microsoft Communications Dlp' }
        ENTERPRISEPREMIUM_CUSTOMER_KEY { 'O365 E5 - Microsoft Customer Key' }
        ENTERPRISEPREMIUM_DATA_INVESTIGATIONS { 'O365 E5 - Microsoft Data Investigations' }
        ENTERPRISEPREMIUM_DESKLESS { 'O365 E5 - Microsoft StaffHub' }
        ENTERPRISEPREMIUM_DYN365_CDS_O365_P3 { 'O365 E5 - Common Data Service' }
        ENTERPRISEPREMIUM_EQUIVIO_ANALYTICS { 'O365 E5 - Office 365 Advanced eDiscovery' }
        ENTERPRISEPREMIUM_EXCHANGE_ANALYTICS { 'O365 E5 - Delve Analytics' }
        ENTERPRISEPREMIUM_EXCHANGE_S_ENTERPRISE { 'O365 E5 - Exchange Online (P2)' }
        ENTERPRISEPREMIUM_FACULTY { 'Office 365 A5 for Faculty' }
        ENTERPRISEPREMIUM_FLOW_O365_P3 { 'O365 E5 - Flow for Office 365' }
        ENTERPRISEPREMIUM_FORMS_PLAN_E5 { 'O365 E5 - Microsoft Forms (Plan E5)' }
        ENTERPRISEPREMIUM_INFO_GOVERNANCE { 'O365 E5 - Microsoft Information Governance' }
        ENTERPRISEPREMIUM_INFORMATION_BARRIERS { 'O365 E5 - Information Barriers' }
        ENTERPRISEPREMIUM_INTUNE_O365 { 'O365 E5 - Microsoft Intune' }
        ENTERPRISEPREMIUM_KAIZALA_STANDALONE { 'O365 E5 - Microsoft Kaizala Pro' }
        ENTERPRISEPREMIUM_LOCKBOX_ENTERPRISE { 'O365 E5 - Customer Lockbox' }
        ENTERPRISEPREMIUM_M365_ADVANCED_AUDITING { 'O365 E5 - Microsoft 365 Advanced Auditing' }
        ENTERPRISEPREMIUM_MCOEV { 'O365 E5 - Microsoft Phone System' }
        ENTERPRISEPREMIUM_MCOMEETADV { 'O365 E5 - Audio Conferencing' }
        ENTERPRISEPREMIUM_MCOSTANDARD { 'O365 E5 - Skype for Business Online (P2)' }
        ENTERPRISEPREMIUM_MICROSOFTBOOKINGS { 'O365 E5 - Microsoft Bookings' }
        ENTERPRISEPREMIUM_MIP_S_CLP1 { 'O365 E5 - Information Protection for Office 365 - Standard' }
        ENTERPRISEPREMIUM_MIP_S_CLP2 { 'O365 E5 - Information Protection for Office 365 - Premium' }
        ENTERPRISEPREMIUM_MTP { 'O365 E5 - Microsoft Threat Protection' }
        ENTERPRISEPREMIUM_MYANALYTICS_P2 { 'O365 E5 - Insights by MyAnalytics' }
        ENTERPRISEPREMIUM_NOPSTNCONF { 'Office 365 E5 Without Audio Conferencing' }
        ENTERPRISEPREMIUM_NOPSTNCONF_ADALLOM_S_O365 { 'O365 E5 Without Audio Conferencing - Office 365 Advanced Security Management' }
        ENTERPRISEPREMIUM_NOPSTNCONF_BI_AZURE_P2 { 'O365 E5 Without Audio Conferencing - Power BI Pro' }
        ENTERPRISEPREMIUM_NOPSTNCONF_DESKLESS { 'O365 E5 Without Audio Conferencing - Microsoft StaffHub' }
        ENTERPRISEPREMIUM_NOPSTNCONF_EQUIVIO_ANALYTICS { 'O365 E5 Without Audio Conferencing - Office 365 Advanced eDiscovery' }
        ENTERPRISEPREMIUM_NOPSTNCONF_EXCHANGE_ANALYTICS { 'O365 E5 Without Audio Conferencing - Delve Analytics' }
        ENTERPRISEPREMIUM_NOPSTNCONF_EXCHANGE_S_ENTERPRISE { 'O365 E5 Without Audio Conferencing - Exchange Online (P2)' }
        ENTERPRISEPREMIUM_NOPSTNCONF_FLOW_O365_P3 { 'O365 E5 Without Audio Conferencing - Flow for Office 365' }
        ENTERPRISEPREMIUM_NOPSTNCONF_FORMS_PLAN_E5 { 'O365 E5 Without Audio Conferencing - Microsft Forms (Plan E5)' }
        ENTERPRISEPREMIUM_NOPSTNCONF_LOCKBOX_ENTERPRISE { 'O365 E5 Without Audio Conferencing - Customer Lockbox' }
        ENTERPRISEPREMIUM_NOPSTNCONF_MCOEV { 'O365 E5 Without Audio Conferencing - Microsoft Phone System' }
        ENTERPRISEPREMIUM_NOPSTNCONF_MCOSTANDARD { 'O365 E5 Without Audio Conferencing - Skype for Business Online (P2)' }
        ENTERPRISEPREMIUM_NOPSTNCONF_OFFICESUBSCRIPTION { 'O365 E5 Without Audio Conferencing - Office 365 ProPlus' }
        ENTERPRISEPREMIUM_NOPSTNCONF_POWERAPPS_O365_P3 { 'O365 E5 Without Audio Conferencing - PowerApps for Office 365' }
        ENTERPRISEPREMIUM_NOPSTNCONF_PROJECTWORKMANAGEMENT { 'O365 E5 Without Audio Conferencing - Microsoft Planner' }
        ENTERPRISEPREMIUM_NOPSTNCONF_RMS_S_ENTERPRISE { 'O365 E5 Without Audio Conferencing - Azure Rights Management' }
        ENTERPRISEPREMIUM_NOPSTNCONF_SHAREPOINTENTERPRISE { 'O365 E5 Without Audio Conferencing - SharePoint (P2)' }
        ENTERPRISEPREMIUM_NOPSTNCONF_SHAREPOINTWAC { 'O365 E5 Without Audio Conferencing - Office for web' }
        ENTERPRISEPREMIUM_NOPSTNCONF_STREAM_O365_E5 { 'O365 E5 Without Audio Conferencing - Stream for Office 365' }
        ENTERPRISEPREMIUM_NOPSTNCONF_SWAY { 'O365 E5 Without Audio Conferencing - Sway' }
        ENTERPRISEPREMIUM_NOPSTNCONF_TEAMS1 { 'O365 E5 Without Audio Conferencing - Microsoft Teams' }
        ENTERPRISEPREMIUM_NOPSTNCONF_THREAT_INTELLIGENCE { 'O365 E5 Without Audio Conferencing - Office 365 Threat Intelligence' }
        ENTERPRISEPREMIUM_NOPSTNCONF_YAMMER_ENTERPRISE { 'O365 E5 Without Audio Conferencing - Yammer Enterprise' }
        ENTERPRISEPREMIUM_OFFICESUBSCRIPTION { 'O365 E5 - Office 365 ProPlus' }
        ENTERPRISEPREMIUM_PAM_ENTERPRISE { 'O365 E5 - Office 365 Privileged Access Management' }
        ENTERPRISEPREMIUM_POWERAPPS_O365_P3 { 'O365 E5 - PowerApps for Office 365' }
        ENTERPRISEPREMIUM_PREMIUM_ENCRYPTION { 'O365 E5 - Premium Encryption in Office 365' }
        ENTERPRISEPREMIUM_PROJECTWORKMANAGEMENT { 'O365 E5 - Microsoft Planner' }
        ENTERPRISEPREMIUM_RECORDS_MANAGEMENT { 'O365 E5 - Microsoft Records Management' }
        ENTERPRISEPREMIUM_RMS_S_ENTERPRISE { 'O365 E5 - Azure Rights Management' }
        ENTERPRISEPREMIUM_SHAREPOINTWAC { 'O365 E5 - SharePoint (P2)' }
        ENTERPRISEPREMIUM_STREAM_O365_E5 { 'O365 E5 - Stream for Office 365' }
        ENTERPRISEPREMIUM_STUDENT { 'Office 365 A5 for Students' }
        ENTERPRISEPREMIUM_SWAY { 'O365 E5 - Sway' }
        ENTERPRISEPREMIUM_TEAMS1 { 'O365 E5 - Microsoft Teams' }
        ENTERPRISEPREMIUM_THREAT_INTELLIGENCE { 'O365 E5 - Office 365 Threat Intelligence' }
        ENTERPRISEPREMIUM_WHITEBOARD_PLAN3 { 'O365 E5 - Whiteboard (P3)' }
        ENTERPRISEPREMIUM_YAMMER_ENTERPRISE { 'O365 E5 - Yammer Enterprise' }
        ENTERPRISEWITHSCAL { 'Office 365 E4' }
        ENTERPRISEWITHSCAL { 'Office 365 Enterprise E4' }
        ENTERPRISEWITHSCAL_DESKLESS { 'O365 E4 - Microsoft StaffHub' }
        ENTERPRISEWITHSCAL_EXCHANGE_S_ENTERPRISE { 'O365 E4 - Exchange Online (P2)' }
        ENTERPRISEWITHSCAL_FACULTY { 'Office 365 Education E4 for Faculty' }
        ENTERPRISEWITHSCAL_FLOW_O365_P2 { 'O365 E4 - Flow for Office 365' }
        ENTERPRISEWITHSCAL_FORMS_PLAN_E3 { 'O365 E4 - Microsft Forms (Plan E3)' }
        ENTERPRISEWITHSCAL_GOV { 'Office 365 Enterprise E4 for Government' }
        ENTERPRISEWITHSCAL_MCOSTANDARD { 'O365 E4 - Skype for Business Online (P2)' }
        ENTERPRISEWITHSCAL_MCOVOICECONF { 'O365 E4 - Audio Conferencing' }
        ENTERPRISEWITHSCAL_OFFICESUBSCRIPTION { 'O365 E4 - Office 365 ProPlus' }
        ENTERPRISEWITHSCAL_POWERAPPS_O365_P2 { 'O365 E4 - PowerApps for Office 365' }
        ENTERPRISEWITHSCAL_PROJECTWORKMANAGEMENT { 'O365 E4 - Microsoft Planner' }
        ENTERPRISEWITHSCAL_RMS_S_ENTERPRISE { 'O365 E4 - Azure Rights Management' }
        ENTERPRISEWITHSCAL_SHAREPOINTENTERPRISE { 'O365 E4 - SharePoint (P2)' }
        ENTERPRISEWITHSCAL_SHAREPOINTWAC { 'O365 E4 - Office for web' }
        ENTERPRISEWITHSCAL_STREAM_O365_E3 { 'O365 E4 - Stream for Office 365' }
        ENTERPRISEWITHSCAL_STUDENT { 'Office 365 Education E4 for Students' }
        ENTERPRISEWITHSCAL_SWAY { 'O365 E4 - Sway' }
        ENTERPRISEWITHSCAL_TEAMS1 { 'O365 E4 - Microsoft Teams' }
        ENTERPRISEWITHSCAL_YAMMER_ENTERPRISE { 'O365 E4 - Yammer Enterprise' }
        EOP_ENTERPRISE { 'Exchange Online Protection' }
        EOP_ENTERPRISE_FACULTY { 'Exchange Online Protection for Faculty' }
        EOP_ENTERPRISE_GOV { 'Exchange Protection for Government' }
        EOP_ENTERPRISE_PREMIUM { 'Exchange Enterprise CAL Services (EOP, DLP)' }
        EOP_ENTERPRISE_STUDENT { 'Exchange Protection for Student' }
        EQUIVIO_ANALYTICS { 'Office 365 Advanced Compliance' }
        EQUIVIO_ANALYTICS_FACULTY { 'Office 365 Advanced Compliance for Faculty' }
        EXCHANGE_ANALYTICS { 'Microsoft Myanalytics (full)' }
        EXCHANGE_B_STANDARD { 'Exchange Online Pop' }
        EXCHANGE_L_STANDARD { 'Exchange Online (P1)' }
        EXCHANGE_ONLINE_WITH_ONEDRIVE_LITE { 'Exchange with OneDrive for Business' }
        EXCHANGE_S_ARCHIVE { 'Exchange Online Archiving for Exchange Server' }
        EXCHANGE_S_ARCHIVE_ADDON { 'Exchange Online Archiving for Exchange Online' }
        EXCHANGE_S_ARCHIVE_ADDON_GOV { 'Exchange Online Archiving' }
        EXCHANGE_S_DESKLESS { 'Exchange Online Kiosk' }
        EXCHANGE_S_DESKLESS_GOV { 'Exchange Online Kiosk for Government' }
        EXCHANGE_S_ENTERPRISE { 'Exchange Online (Plan 2)' }
        EXCHANGE_S_ENTERPRISE_GOV { 'Exchange Online P2 for Government' }
        EXCHANGE_S_ESSENTIALS { 'Exchange Online Essentials' }
        EXCHANGE_S_ESSENTIALS_EXCHANGE_S_ESSENTIALS { 'Exchange Online Essentials' }
        EXCHANGE_S_FOUNDATION { 'Exchange Foundation' }
        EXCHANGE_S_STANDARD { 'Exchange Online (Plan 1)' }
        EXCHANGE_S_STANDARD_MIDMARKET { 'Exchange Online Plan 1' }
        EXCHANGE_STANDARD_ALUMNI { 'Exchange Online (Plan 1) for alumni' }
        EXCHANGEARCHIVE { 'Exchange Online Archiving for Exchange Server' }
        EXCHANGEARCHIVE_ADDON { 'Exchange Online Archiving for Exchange Online' }
        EXCHANGEARCHIVE_ADDON_EXCHANGE_S_ARCHIVE_ADDON { 'Exchange Online Archiving for Exchange Online' }
        EXCHANGEARCHIVE_EXCHANGE_S_ARCHIVE { 'Exchange Online Archiving for Exchange Server' }
        EXCHANGEARCHIVE_FACULTY { 'Exchange Archiving for Faculty' }
        EXCHANGEARCHIVE_GOV { 'Exchange Archiving for Government' }
        EXCHANGEARCHIVE_STUDENT { 'Exchange Archiving for Students' }
        EXCHANGEDESKLESS { 'Exchange Online Kiosk' }
        EXCHANGEDESKLESS { 'Exchange Online Kiosk' }
        EXCHANGEDESKLESS_EXCHANGE_S_DESKLESS { 'Exchange Online Kiosk' }
        EXCHANGEDESKLESS_GOV { 'Exchange Kiosk for Government' }
        EXCHANGEENTERPRISE { 'Exchange Online (Plan 2)' }
        EXCHANGEENTERPRISE { 'Exchange Online Plan 2' }
        EXCHANGEENTERPRISE_BPOS_S_TODO_1 { 'Exchange Online (P2) - To-do (P1)' }
        EXCHANGEENTERPRISE_EXCHANGE_S_ENTERPRISE { 'Exchange Online (P2) - Exchange Online (P2)' }
        EXCHANGEENTERPRISE_FACULTY { 'Exchange Online (Plan 2) for Faculty' }
        EXCHANGEENTERPRISE_GOV { 'Exchange Online Plan 2 for Government' }
        EXCHANGEENTERPRISE_STUDENT { 'Exchange Online (Plan 2) for Student' }
        EXCHANGEESSENTIALS { 'Exchange Online Essentials' }
        EXCHANGEESSENTIALS_EXCHANGE_S_STANDARD { 'Exchange Online Essentials' }
        EXCHANGESTANDARD { 'Exchange Online (Plan 1)' }
        EXCHANGESTANDARD_EXCHANGE_S_STANDARD { 'Exchange Online (Plan 1)' }
        EXCHANGESTANDARD_FACULTY { 'Exchange (Plan 1 for Faculty)' }
        EXCHANGESTANDARD_GOV { 'Exchange Online P1 for Government' }
        EXCHANGESTANDARD_STUDENT { 'Exchange Online P1 for Students' }
        EXCHANGETELCO { 'Exchange Online Pop' }
        FLOW_DYN_APPS { 'Flow for Dynamics 365' }
        FLOW_DYN_P2 { 'Flow for Dynamics 365' }
        FLOW_DYN_TEAM { 'Flow for Dynamics 365' }
        FLOW_FOR_PROJECT { 'Flow for Project Online' }
        FLOW_FREE { 'Microsoft Power Automate Free' }
        FLOW_FREE_DYN365_CDS_VIRAL { 'Flow Free - Common Data Service' }
        FLOW_FREE_FLOW_P2_VIRAL { ' Flow Free - Flow Free' }
        FLOW_O365_P1 { 'Flow for Office 365' }
        FLOW_O365_P2 { 'Flow for Office 365' }
        FLOW_O365_P3 { 'Flow for Office 365' }
        FLOW_O365_S1 { 'Flow for Office 365 K1' }
        FLOW_P1 { 'Microsoft Flow Plan 1' }
        FLOW_P2 { 'Microsoft Flow Plan 2' }
        FLOW_P2_DYN365_CDS_P2 { ' Microsoft Flow Plan 2 - Common Data Service' }
        FLOW_P2_FLOW_P2 { 'Microsoft Flow Plan 2' }
        FLOW_P2_VIRAL { 'Flow Free' }
        FLOW_P2_VIRAL_REAL { 'Flow P2 Viral' }
        FLOW_PER_USER { 'Power Automate per user plan' }
        FORMS_PLAN_E1 { 'Microsoft Forms (Plan E1)' }
        FORMS_PLAN_E3 { 'Microsoft Forms (Plan E3)' }
        FORMS_PLAN_E5 { 'Microsoft Forms (Plan E5)' }
        FORMS_PLAN_K { 'Microsoft Forms (Plan F1)' }
        FORMS_PRO { 'Forms Pro Trial' }
        FORMS_PRO_DYN365_CDS_FORMS_PRO { 'Forms Pro Trial - Common Data Service' }
        FORMS_PRO_FLOW_FORMS_PRO { 'Forms Pro Trial- Microsoft Flow' }
        FORMS_PRO_FORMS_PLAN_E5 { 'Forms Pro Trial - Microsoft Forms (Plan E5)' }
        FORMS_PRO_FORMS_PRO { 'Forms Pro Trial' }
        Forms_Pro_USL { 'Microsoft Forms Pro (USL)' }
        GLOBAL_SERVICE_MONITOR { 'Global Service Monitor Online Service' }
        GUIDES_USER_DYN365_CDS_GUIDES { 'User Guides - Common Data Service' }
        GUIDES_USER_GUIDES { 'User Guides' }
        GUIDES_USER_POWERAPPS_GUIDES { 'User Guides - PowerApps' }
        IDENTITY_THREAT_PROTECTION { 'Microsoft 365 E5 Security' }
        IDENTITY_THREAT_PROTECTION_FOR_EMS_E5 { 'Microsoft 365 E5 Security for EMS E5' }
        INFO_GOVERNANCE { 'Microsoft Information Governance' }
        INFOPROTECTION_P2 { 'Azure Information Protection Premium P2' }
        INFORMATION_BARRIERS { 'Information Barriers' }
        INFORMATION_PROTECTION_COMPLIANCE { 'Microsoft 365 E5 Compliance' }
        INTUNE_A { 'Intune' }
        INTUNE_A_D { 'Microsoft Intune Device' }
        INTUNE_A_INTUNE_A { 'Microsoft Intune' }
        INTUNE_A_VL { 'Intune VL' }
        INTUNE_A_VL_INTUNE_A_VL { 'Microsoft Intune VL' }
        INTUNE_EDU { 'Intune for Education' }
        INTUNE_O365 { 'Mobile Device Management for Office 365' }
        INTUNE_O365_STANDALONE { 'Mobile Device Management for Office 365' }
        INTUNE_SMB { 'Microsoft Intune SMB' }
        INTUNE_SMBIZ { 'Microsoft Intune SMBIZ' }
        IT_ACADEMY_AD { 'Ms Imagine Academy' }
        IT_ACADEMY_AD_IT_ACADEMY_AD { 'Ms Imagine Academy' }
        IWsPROJECT_MADEIRA_PREVIEW_IW_SKU { 'Dynamics 365 Business Central for' }
        KAIZALA_O365_P1 { 'Microsoft Kaizala Pro Plan 1' }
        KAIZALA_O365_P3 { 'Microsoft Kaizala Pro Plan 3' }
        KAIZALA_STANDALONE { 'Microsoft Kaizala' }
        KAIZALA_STUDENT { 'Microsoft Kaizala Pro for students' }
        LITEPACK { 'Office 365 Small Business' }
        LITEPACK_EXCHANGE_L_STANDARD { 'O365 Small Business - Exchange Online (P1)' }
        LITEPACK_MCOLITE { 'O365 Small Business - Skype for Business Online (P1)' }
        LITEPACK_P2 { 'Office 365 Small Business Premium' }
        LITEPACK_P2_EXCHANGE_L_STANDARD { 'Office 365 Small Business Premium - Exchange Online (P1)' }
        LITEPACK_P3_MCOLITE { 'Office 365 Small Business Premium - Skype for Business Online (P1)' }
        LITEPACK_P4_OFFICE_PRO_PLUS_SUBSCRIPTION_SMBIZ { 'Office 365 Small Business Premium - Office 365 ProPlus' }
        LITEPACK_P5_SHAREPOINTLITE { 'Office 365 Small Business Premium - Sharepointlite' }
        LITEPACK_P6_SWAY { 'Office 365 Small Business Premium - Sway' }
        LITEPACK_SHAREPOINTLITE { 'O365 Small Business - Sharepointlite' }
        LITEPACK_SWAY { 'O365 Small Business - Sway' }
        LOCKBOX { 'Customer Lockbox' }
        LOCKBOX_ENTERPRISE { 'Customer Lockbox' }
        M365EDU_A3_STUUSEBNFT { 'Microsoft 365 A3 for students use benefit' }
        M365EDU_A5_NOPSTNCONF_FACULTY { 'Microsoft 365 A5 without Audio Conferencing for faculty' }
        M365_ADVANCED_AUDITING { 'Microsoft 365 Advanced Auditing' }
        M365_E5_SUITE_COMPONENTS { 'Microsoft 365 E5 Suite features' }
        M365_F1 { 'Microsoft 365 F1' }
        M365_F1_AAD_PREMIUM { 'M365 F1 - Azure AD Premium P1' }
        M365_F1_ADALLOM_S_DISCOVERY { 'M365 F1 - Cloud App Security Discovery' }
        M365_F1_DYN365_CDS_O365_F1 { 'M365 F1 - Common Data Service' }
        M365_F1_EXCHANGE_S_DESKLESS { 'M365 F1 - Exchange Online Kiosk' }
        M365_F1_INTUNE_A { 'M365 F1 - Microsoft Intune' }
        M365_F1_MCOIMP { 'M365 F1 - Skype for Business Online (P1)' }
        M365_F1_MFA_PREMIUM { 'M365 F1 - Azure Multi-factor Authentication' }
        M365_F1_PROJECTWORKMANAGEMENT { 'M365 F1 - Microsoft Planner' }
        M365_F1_RMS_S_ENTERPRISE_GOV { 'M365 F1 - Azure Rights Management' }
        M365_F1_RMS_S_PREMIUM { 'M365 F1 - Azure Information Protection P1' }
        M365_F1_SHAREPOINTDESKLESS { 'M365 F1 - Sharepoint Online Kiosk' }
        M365_F1_STREAM_O365_K { 'M365 F1 - Microsoft Stream for O365 K SKU' }
        M365_F1_TEAMS1 { 'M365 F1 - Microsoft Teams' }
        M365_F1_YAMMER_ENTERPRISE { 'M365 F1 - Yammer Enterprise' }
        M365_G3_GOV { 'Microsoft 365 G3 GCC' }
        M365_SECURITY_COMPLIANCE_FOR_FLW { 'Microsoft 365 Security and Compliance for FLW' }
        M365EDU_A1 { 'Microsoft 365 A1' }
        M365EDU_A3_FACULTY { 'Microsoft 365 A3 for Faculty' }
        M365EDU_A3_STUDENT { 'Microsoft 365 A3 for Students' }
        M365EDU_A5_FACULTY { 'Microsoft 365 A5 for Faculty' }
        M365EDU_A5_STUDENT { 'Microsoft 365 A5 for Students' }
        MCOCAP { 'Common Area Phone' }
        MCO_TEAMS_IW { 'Microsoft Teams (Conferencing)' }
        MCOCAP_MCOEV { 'Common Area Phone - Microsoft Phone System' }
        MCOCAP_MCOSTANDARD { 'Common Area Phone - Skype for Business Online (P2)' }
        MCOCAP_TEAMS1 { 'Common Area Phone - Microsoft Teams' }
        MCOEV { 'Microsoft Teams Phone Standard' }
        MCOEV_DOD { 'Microsoft Teams Phone Standardfor DoD' }
        MCOEV_FACULTY { 'Microsoft Teams Phone Standardfor Faculty' }
        MCOEV_GCCHIGH { 'Microsoft Teams Phone for GCC High' }
        MCOEV_GOV { 'Microsoft Teams Phone for GCC' }
        MCOEV_MCOEV { 'Microsoft Teams Phone' }
        MCOEV_STUDENT { 'Microsoft Teams Phone for Students' }
        MCOEV_TELSTRA { 'MMicrosoft Teams Phone for TELSTRA' }
        MCOEV_USGOV_DOD { 'Microsoft Teams Phone for US GOV DoD' }
        MCOEV_USGOV_GCCHIGH { 'Microsoft Teams Phone for US GOV GCC High' }
        MCOEVSMB_1 { 'Microsoft Teams Phone for Small and Medium Business' }
        MCOIMP { 'Skype for Business Online (Plan 1)' }
        MCOIMP_FACULTY { 'Skype for Business Online (Plan 1 for Faculty)' }
        MCOIMP_GOV { 'Skype for Business Online for Government (Plan 1G)' }
        MCOIMP_MCOIMP { 'Skype for Business Online (Plan 1)' }
        MCOIMP_STUDENT { 'Skype for Business Online (Plan 1 for Students)' }
        MCOINTERNAL { 'Lync Internal Incubation and Corp to Cloud' }
        MCOLITE { 'Skype for Business Online (Plan P1)' }
        MCOMEETACPEA { 'Microsoft 365 Audio Conferencing Pay Per Minute' }
        MCOMEETADV { 'Microsoft 365 Audio Conferencing' }
        MCOMEETADV_GOC { 'Microsoft 365 Audio Conferencing for GCC' }
        MCOMEETADV_MCOMEETADV { 'Microsoft 365 Audio Conferencing' }
        MCOPSTN1 { 'Microsoft 365 Domestic Calling Plan' }
        MCOPSTN1_MCOPSTN1 { 'Microsoft 365 Domestic Calling Plan' }
        MCOPSTN2 { 'Microsoft 365 Domestic And International Calling Plan' }
        MCOPSTN2_MCOPSTN2 { 'Microsoft 365 Domestic And International Calling Plan' }
        MCOPSTN5 { 'Skype for Business PSTN Domestic Calling' }
        MCOPSTN_5 { 'Microsoft 365 Domestic Calling Plan (120 min)' }
        MCOPSTN_5_MCOPSTN5 { 'Microsoft 365 Domestic Calling Plan (120 min)' }
        MCOPSTNC { 'Communication Credits' }
        MCOPSTNC_MCOPSTNC { 'Skype for Business Communications Credits' }
        MCOPSTNEAU2 { 'TELSTRA Calling for O365' }
        MCOPSTNPP { 'Skype for Business Communication Credits - Paid' }
        MCOSTANDARD { 'Skype for Business Online (Plan 2)' }
        MCOSTANDARD_FACULTY { 'Skype for Business Online (Plan 2 for Faculty)' }
        MCOSTANDARD_GOV { 'Skype for Business Online P2 for Government' }
        MCOSTANDARD_MCOSTANDARD { 'Skype for Business Online (Plan 2)' }
        MCOSTANDARD_MIDMARKET { 'Skype for Business Online (Plan 2) for Midsize' }
        MCOSTANDARD_STUDENT { 'Skype for Business Online (Plan 2 for Students)' }
        MCOVOICECONF { 'Skype for Business Online (Plan 3)' }
        MCOVOICECONF_FACULTY { 'Skype for Business Online Plan 3 for Faculty' }
        MCOVOICECONF_GOV { 'Skype for Business Online for Government (Plan 3G)' }
        MCOVOICECONF_STUDENT { 'Skype for Business Online Plan 3 for Students' }
        MCVOICECONF { 'Skype for Business Online P3' }
        MDATP_XPLAT { 'Microsoft Defender For Endpoint' }
        MDM_SALES_COLLABORATION { 'Microsoft Dynamics Marketing Sales Collaboration' }
        MEE_FACULTY { 'Minecraft Education Edition Faculty' }
        MEE_STUDENT { 'Minecraft Education Edition Student' }
        MEETING_ROOM { 'Microsoft Teams Rooms Standard' }
        MEETING_ROOM_INTUNE_A { 'Meeting Room - Microsoft Intune' }
        MEETING_ROOM_MCOEV { 'Meeting Room - Microsoft Phone System' }
        MEETING_ROOM_MCOMEETADV { 'Meeting Room - Audio Conferencing' }
        MEETING_ROOM_MCOSTANDARD { 'Meeting Room - Skype for Business Online (P2)' }
        MEETING_ROOM_TEAMS1 { 'Meeting Room - Microsoft Teams' }
        MFA_PREMIUM { 'Microsoft Azure Multi-factor Authentication' }
        MFA_STANDALONE { 'Azure Multi-Factor Authentication Premium Standalone' }
        MICROSOFT_BUSINESS_CENTER { 'Microsoft Business Center' }
        MICROSOFT_REMOTE_ASSIST { 'Dynamics 365 Remote Assist' }
        MICROSOFT_REMOTE_ASSIST_CDS_REMOTE_ASSIST { 'Microsoft Remote Assistant - Common Data Service' }
        MICROSOFT_REMOTE_ASSIST_HOLOLENS { 'Dynamics 365 Remote Assist HoloLens' }
        MICROSOFT_REMOTE_ASSIST_MICROSOFT_REMOTE_ASSIST { 'Microsoft Remote Assistant' }
        MICROSOFT_REMOTE_ASSIST_TEAMS1 { 'Microsoft Remote Assistant - Microsft Teams' }
        MICROSOFT_SEARCH { 'Microsoft Search' }
        MICROSOFTBOOKINGS { 'Microsoft Bookings' }
        MIDSIZEPACK { 'Office 365 Midsize Business' }
        MIDSIZEPACK_EXCHANGE_S_STANDARD_MIDMARKET { 'O365 Midsize Business - Exchange Online (P1)' }
        MIDSIZEPACK_MCOSTANDARD_MIDMARKET { 'O365 Midsize Business - Skype for Business Online (P2)' }
        MIDSIZEPACK_OFFICESUBSCRIPTION { 'O365 Midsize Business - Office 365 ProPlus' }
        MIDSIZEPACK_SHAREPOINTENTERPRISE_MIDMARKET { 'O365 Midsize Business - SharePoint Online (P1)' }
        MIDSIZEPACK_SHAREPOINTWAC { 'O365 Midsize Business - Office for web' }
        MIDSIZEPACK_SWAY { 'O365 Midsize Business - Sway' }
        MIDSIZEPACK_YAMMER_MIDSIZE { 'O365 Midsize Business - Yammer Enterprise' }
        MINECRAFT_EDUCATION_EDITION { 'Minecraft Education Edition' }
        MIP_S_CLP1 { 'Information Protection for Office 365 - Standard' }
        MIP_S_CLP2 { 'Information Protection for Office 365 - Premium' }
        MS_TEAMS_IW { 'Microsoft Team Trial' }
        MTR_PREM_NOAUDIOCONF_FACULTY { 'Teams Rooms Premium without Audio Conferencing for faculty Trial' }
        MYANALYTICS_P2 { 'Insights By Myanalytics' }
        NBENTERPRISE { 'Microsoft Social Engagement - Service Discontinuation' }
        NBPROFESSIONALFORCRM { 'Microsoft Social Engagement Professional' }
        NONPROFIT_PORTAL { 'Nonprofit Portal' }
        O365_BUSINESS { 'Microsoft 365 Apps for Business' }
        O365_BUSINESS_ESSENTIALS { 'Microsoft 365 Business Basic' }
        O365_BUSINESS_ESSENTIALS_EXCHANGE_S_STANDARD { 'M365 Business Basic - Exchange Online (P2)' }
        O365_BUSINESS_ESSENTIALS_FLOW_O365_P1 { 'M365 Business Basic - Flow for Office 365' }
        O365_BUSINESS_ESSENTIALS_FORMS_PLAN_E1 { 'M365 Business Basic - Microsft Forms (Plan E1)' }
        O365_BUSINESS_ESSENTIALS_MCOSTANDARD { 'M365 Business Basic - Skype for Business Online (P2)' }
        O365_BUSINESS_ESSENTIALS_POWERAPPS_O365_P1 { 'M365 Business Basic - PowerApps for Office 365' }
        O365_BUSINESS_ESSENTIALS_PROJECTWORKMANAGEMENT { 'M365 Business Basic - Microsoft Planner' }
        O365_BUSINESS_ESSENTIALS_SHAREPOINTSTANDARD { 'M365 Business Basic - SharePoint (P1)' }
        O365_BUSINESS_ESSENTIALS_SHAREPOINTWAC { 'M365 Business Basic - Office for web' }
        O365_BUSINESS_ESSENTIALS_SWAY { 'M365 Business Basic - Sway' }
        O365_BUSINESS_ESSENTIALS_TEAMS1 { 'M365 Business Basic - Microsoft Teams' }
        O365_BUSINESS_ESSENTIALS_YAMMER_ENTERPRISE { 'M365 Business Basic - Yammer Enterprise' }
        O365_BUSINESS_FORMS_PLAN_E1 { 'M365 Apps for Business - Microsft Forms (Plan E1)' }
        O365_BUSINESS_OFFICE_BUSINESS { 'M365 Apps for Business - Office 365 Business' }
        O365_BUSINESS_ONEDRIVESTANDARD { 'M365 Apps for Business - OneDrive for Business' }
        O365_BUSINESS_PREMIUM { 'Microsoft 365 Business Standard' }
        O365_BUSINESS_PREMIUM_BPOS_S_TODO_1 { 'M365 Business Standard - To-do (P1)' }
        O365_BUSINESS_PREMIUM_DESKLESS { 'M365 Business Standard - Microsoft StaffHub' }
        O365_BUSINESS_PREMIUM_DYN365_CDS_O365_P2 { 'M365 Business Standard - Common Data Service' }
        O365_BUSINESS_PREMIUM_DYN365BC_MS_INVOICING { 'M365 Business Standard - Microsoft Invoicing' }
        O365_BUSINESS_PREMIUM_EXCHANGE_S_STANDARD { 'M365 Business Standard - Exchange Online (P2)' }
        O365_BUSINESS_PREMIUM_FLOW_O365_P1 { 'M365 Business Standard - Flow for Office 365' }
        O365_BUSINESS_PREMIUM_FORMS_PLAN_E1 { 'M365 Business Standard - Microsft Forms (Plan E1)' }
        O365_BUSINESS_PREMIUM_KAIZALA_O365_P2 { 'M365 Business Standard - Microsoft Kaizala Pro' }
        O365_BUSINESS_PREMIUM_MCOSTANDARD { 'M365 Business Standard - Skype for Business Online (P2)' }
        O365_BUSINESS_PREMIUM_MICROSOFTBOOKINGS { 'M365 Business Standard - Microsoft Bookings' }
        O365_BUSINESS_PREMIUM_MYANALYTICS_P2 { 'M365 Business Standard - Insights by MyAnalytics' }
        O365_BUSINESS_PREMIUM_O365_SB_RELATIONSHIP_MANAGEMENT { 'M365 Business Standard - Outlook Customer Manager' }
        O365_BUSINESS_PREMIUM_OFFICE_BUSINESS { 'M365 Business Standard - Office 365 Business' }
        O365_BUSINESS_PREMIUM_POWERAPPS_O365_P1 { 'M365 Business Standard - PowerApps for Office 365' }
        O365_BUSINESS_PREMIUM_PROJECTWORKMANAGEMENT { 'M365 Business Standard - Microsoft Planner' }
        O365_BUSINESS_PREMIUM_SHAREPOINTSTANDARD { 'M365 Business Standard - SharePoint (P1)' }
        O365_BUSINESS_PREMIUM_SHAREPOINTWAC { 'M365 Business Standard - Office for web' }
        O365_BUSINESS_PREMIUM_STREAM_O365_SMB { 'M365 Business Standard - Stream for Office 365' }
        O365_BUSINESS_PREMIUM_SWAY { 'M365 Business Standard - Sway' }
        O365_BUSINESS_PREMIUM_TEAMS1 { 'M365 Business Standard - Microsoft Teams' }
        O365_BUSINESS_PREMIUM_WHITEBOARD_PLAN1 { 'M365 Business Standard - Whiteboard (P1)' }
        O365_BUSINESS_PREMIUM_YAMMER_ENTERPRISE { 'M365 Business Standard - Yammer Enterprise' }
        O365_BUSINESS_SHAREPOINTWAC { 'M365 Apps for Business - Office for web' }
        O365_BUSINESS_SWAY { 'M365 Apps for Business - Sway' }
        O365_SB_Relationship_Management { 'Outlook Customer Manager' }
        OFFICE_BASIC { 'Office 365 Basic' }
        OFFICE_BUSINESS { 'Office 365 Business' }
        OFFICE_FORMS_PLAN_2 { 'Microsoft Forms (Plan 2)' }
        OFFICE_FORMS_PLAN_3 { 'Microsoft Forms (Plan 3)' }
        OFFICE365_MULTIGEO { 'Multi-Geo Capabilities in Office 365' }
        OFFICEMOBILE_SUBSCRIPTION { 'OFFICEMOBILE_SUBSCRIPTION' }
        OFFICESUBSCRIPTION { 'Microsoft 365 Apps for Enterprise' }
        OFFICESUBSCRIPTION_FACULTY { 'Office 365 ProPlus for Faculty' }
        OFFICESUBSCRIPTION_FORMS_PLAN_E1 { 'M365 Apps for Enterprise - Microsft Forms (Plan E1)' }
        OFFICESUBSCRIPTION_GOV { 'Office 365 ProPlus for Government' }
        OFFICESUBSCRIPTION_OFFICESUBSCRIPTION { 'M365 Apps for Enterprise - Office 365 ProPlus' }
        OFFICESUBSCRIPTION_ONEDRIVESTANDARD { 'M365 Apps for Enterprise - OneDrive for Business' }
        OFFICESUBSCRIPTION_SHAREPOINTWAC { 'M365 Apps for Enterprise - Office for web' }
        OFFICESUBSCRIPTION_STUDENT { 'Microsoft 365 Apps for Students' }
        OFFICESUBSCRIPTION_SWAY { 'M365 Apps for Enterprise - Sway' }
        ONEDRIVE_BASIC { 'OneDrive Basic' }
        ONEDRIVEBASIC { 'OneDrive Basic' }
        ONEDRIVEENTERPRISE { 'Onedriveenterprise' }
        ONEDRIVESTANDARD { 'Onedrivestandard' }
        ONEDRIVESTANDARD_GOV { 'OneDrive for Business for Government (Plan 1G)' }
        PAM_ENTERPRISE { 'Office 365 Privileged Access Management' }
        PARATURE_ENTERPRISE { 'Parature Enterprise' }
        PARATURE_ENTERPRISE_GOV { 'Parature Enterprise for Government' }
        PHONESYSTEM_VIRTUALUSER { 'Virtual Phone System User' }
        PHONESYSTEM_VIRTUALUSER_MCOEV_VIRTUALUSER { 'Microsoft 365 Phone System - Virtual User' }
        PLANNERSTANDALONE { 'Planner Standalone' }
        POWER_BI_ADDON { 'Power BI for Office 365 Add-on' }
        POWER_BI_ADDON_BI_AZURE_P1 { 'Power BI for O365 Add-on - Microsoft Power BI Reporting And Analytics Plan 1' }
        POWER_BI_ADDON_SQL_IS_SSIM { 'Power BI for O365 Add-on - Microsoft Power BI Information Services Plan 1' }
        POWER_BI_INDIVIDUAL_USE { 'Power BI Individual User' }
        POWER_BI_INDIVIDUAL_USER { 'Power BI for Office 365 Individual' }
        POWER_BI_PRO { 'Power BI Pro' }
        POWER_BI_PRO_BI_AZURE_P2 { 'POWER BI PRO - Power BI Pro' }
        POWER_BI_PRO_CE { 'Power BI Pro (Nonprofit Staff Pricing)' }
        POWER_BI_PRO_FACULTY { 'Power BI Pro for faculty' }
        POWER_BI_PRO_STUDENT { 'Power BI Pro for students' }
        POWER_BI_STANDALONE { 'Power BI for Office 365 Standalone' }
        POWER_BI_STANDALONE_FACULTY { 'Power BI for Office 365 for Faculty' }
        POWER_BI_STANDALONE_STUDENT { 'Power BI for Office 365 for Students' }
        POWER_BI_STANDARD { 'Power BI (free)' }
        POWER_BI_STANDARD_BI_AZURE_P0 { 'Power BI (free)' }
        POWER_BI_STANDARD_FACULTY { 'Power BI (free) for Faculty' }
        POWER_BI_STANDARD_STUDENT { 'Power BI (free) for Students' }
        POWERAPPS_DEV { 'Power Apps for Developer' }
        POWERAPPS_DYN_APPS { 'Powerapps for Dynamics 365' }
        POWERAPPS_DYN_P2 { 'Powerapps for Dynamics 365' }
        POWERAPPS_DYN_TEAM { 'Powerapps for Dynamics 365' }
        POWERAPPS_INDIVIDUAL_USER { 'Microsoft PowerApps and Logic Flows' }
        POWERAPPS_INDIVIDUAL_USER_POWERAPPSFREE { 'Microsoft PowerApps and Logic Flows - Microsoft PowerApps' }
        POWERAPPS_INDIVIDUAL_USER_POWERFLOWSFREE { 'Microsoft PowerApps and Logic Flows - Logic Flows' }
        POWERAPPS_INDIVIDUAL_USER_POWERVIDEOSFREE { 'Microsoft PowerApps and Logic Flows - Microsoft Power Videos Basic' }
        POWERAPPS_O365_P1 { 'Powerapps for Office 365' }
        POWERAPPS_O365_P2 { 'Powerapps for Office 365' }
        POWERAPPS_O365_P3 { 'Powerapps for Office 365 Plan 3' }
        POWERAPPS_O365_S1 { 'Powerapps for Office 365 K1' }
        POWERAPPS_P2_VIRAL { 'PowerApps Trial' }
        POWERAPPS_PER_USER { 'PowerApps Per User Plan' }
        POWERAPPS_PER_APP { 'PowerApps Per App Plan' }
        POWERAPPS_PER_APP_IW { 'PowerApps per app baseline access' }
        POWERAPPS_VIRAL { 'Microsoft PowerApps Plan 2 Trial' }
        POWERAPPS_VIRAL_DYN365_CDS_VIRAL { 'MS PowerApps Plan 2 Trial - Common Data Service' }
        POWERAPPS_VIRAL_FLOW_P2_VIRAL { 'MS PowerApps Plan 2 Trial - Flow Free' }
        POWERAPPS_VIRAL_FLOW_P2_VIRAL_REAL { 'MS PowerApps Plan 2 Trial - Flow P2 Viral' }
        POWERAPPS_VIRAL_POWERAPPS_P2_VIRAL { 'MS PowerApps Plan 2 Trial - PowerApps Trial' }
        POWERAPPSFREE { 'Microsoft PowerApps' }
        POWERAUTOMATE_ATTENDED_RPA { 'Power Automate per user plan with attended RPA' }
        POWERFLOW_P2 { 'Microsoft PowerApps Plan 2 Trial' }
        POWERFLOW_P2_DYN365_CDS_P2 { 'Microsoft PowerApps P2 Trial - Common Data Service' }
        POWERFLOW_P2_FLOW_P2 { 'Microsoft PowerApps P2 Trial' }
        POWERFLOW_P2_POWERAPPS_P2 { 'Microsoft PowerApps P2 Trial - PowerApps' }
        POWERFLOWSFREE { 'Logic flows' }
        POWERVIDEOSFREE { 'Microsoft Power Videos Basic' }
        PREMIUM_ENCRYPTION { 'Premium Encryption In Office 365' }
        PROJECT_CLIENT_SUBSCRIPTION { 'Project Online Desktop Client' }
        PROJECT_ESSENTIALS { 'Project Online Essentials' }
        PROJECT_MADEIRA_PREVIEW_IW_SKU { 'Dynamics 365 for Financials for IWs' }
        PROJECT_MADEIRA_PREVIEW_IW_SKU_PROJECT_MADEIRA_PREVIEW_IW { 'Microsoft Dynamics 365 Business Preview Iw (deprecated)' }
        PROJECT_P1 { 'Project Plan 1' }
        PROJECT_PROFESSIONAL { 'Project Online Professional' }
        PROJECTCLIENT { 'Project for Office 365' }
        PROJECTCLIENT_FACULTY { 'Project Pro for Office 365 for Faculty' }
        PROJECTCLIENT_GOV { 'Project Pro for Office 365 for Government' }
        PROJECTCLIENT_PROJECT_CLIENT_SUBSCRIPTION { 'Project for O365 - Project Online Desktop Client' }
        PROJECTCLIENT_STUDENT { 'Project Pro for Office 365 for Students' }
        PROJECTESSENTIALS { 'Project Online Essentials' }
        PROJECTESSENTIALS_FACULTY { 'Project Online Essentials for Faculty' }
        PROJECTESSENTIALS_FORMS_PLAN_E1 { 'Project Online Essentials - Microsft Forms (Plan E1)' }
        PROJECTESSENTIALS_GOV { 'Project Essentials for Government' }
        PROJECTESSENTIALS_PROJECT_ESSENTIALS { 'Project Online Essentials - Project Online Essential' }
        PROJECTESSENTIALS_SHAREPOINTENTERPRISE { 'Project Online Essentials - SharePoint (P2)' }
        PROJECTESSENTIALS_SHAREPOINTWAC { 'Project Online Essentials - Office for web' }
        PROJECTESSENTIALS_STUDENT { 'Project Online Essentials for Students' }
        PROJECTESSENTIALS_SWAY { 'Project Online Essentials - Sway' }
        PROJECTONLINE_PLAN_1 { 'Project Online Premium Without Project Client' }
        PROJECTONLINE_PLAN_1_FACULTY { 'Project Online for Faculty Plan 1' }
        PROJECTONLINE_PLAN_1_FORMS_PLAN_E1 { 'Project Online Premium Without Project Client - Microsft Forms (Plan E1)' }
        PROJECTONLINE_PLAN_1_GOV { 'Project Plan 1for Government' }
        PROJECTONLINE_PLAN_1_SHAREPOINT_PROJECT { 'Project Online Premium Without Project Client - Project Online Service' }
        PROJECTONLINE_PLAN_1_SHAREPOINTENTERPRISE { 'Project Online Premium Without Project Client - SharePoint (P2)' }
        PROJECTONLINE_PLAN_1_SHAREPOINTWAC { 'Project Online Premium Without Project Client - Office for web' }
        PROJECTONLINE_PLAN_1_STUDENT { 'Project Online for Students Plan 1' }
        PROJECTONLINE_PLAN_1_SWAY { 'Project Online Premium Without Project Client - Sway' }
        PROJECTONLINE_PLAN_2 { 'Project Online With Project for Office 365' }
        PROJECTONLINE_PLAN_2_FACULTY { 'Project Online for Faculty Plan 2' }
        PROJECTONLINE_PLAN_2_FORMS_PLAN_E1 { 'Project Online With Project for O365 - Microsft Forms (Plan E1)' }
        PROJECTONLINE_PLAN_2_GOV { 'Project Plan 2 for Government' }
        PROJECTONLINE_PLAN_2_SHAREPOINT_PROJECT { 'Project Online With Project for O365 - Project Online Service' }
        PROJECTONLINE_PLAN_2_STUDENT { 'Project Online for Students Plan 2' }
        PROJECTONLINE_PLAN_3_PROJECT_CLIENT_SUBSCRIPTION { 'Project Online With Project for O365 - Project Online Desktop Client' }
        PROJECTONLINE_PLAN_3_SHAREPOINTENTERPRISE { 'Project Online Premium Without Project Client - SharePoint (P2)' }
        PROJECTONLINE_PLAN_4_SHAREPOINT_PROJECT { 'Project Online With Project for O365 - Project Online Service' }
        PROJECTONLINE_PLAN_4_SHAREPOINTWAC { 'Project Online Premium Without Project Client - Office for web' }
        PROJECTONLINE_PLAN_5_SHAREPOINTENTERPRISE { 'Project Online With Project for O365 - SharePoint (P2)' }
        PROJECTONLINE_PLAN_5_SWAY { 'Project Online Premium Without Project Client - Sway' }
        PROJECTONLINE_PLAN_6_SHAREPOINTWAC { 'PProject Online With Project for O365 - Office for web' }
        PROJECTONLINE_PLAN_7_SWAY { 'Project Online With Project for O365 - Sway' }
        PROJECTONLINE_PLAN1_FACULTY { 'Project Online Professional P1 for Faculty' }
        PROJECTONLINE_PLAN1_STUDENT { 'Project Online Professional P1 for Students' }
        PROJECTPREMIUM { 'Project Online Premium' }
        PROJECTPREMIUM_PROJECT_CLIENT_SUBSCRIPTION { 'Project Online Premium - Project Online Desktop Client' }
        PROJECTPREMIUM_SHAREPOINT_PROJECT { 'Project Online Premium - Project Online Service' }
        PROJECTPREMIUM_SHAREPOINTENTERPRISE { 'Project Online Premium - SharePoint (P2)' }
        PROJECTPREMIUM_SHAREPOINTWAC { 'Project Online Premium - Office for web' }
        PROJECTPROFESSIONAL { 'Project Online Professional' }
        PROJECTPROFESSIONAL_DYN365_CDS_PROJECT { 'Project Online Professional - Common Data Service' }
        PROJECTPROFESSIONAL_FLOW_FOR_PROJECT { 'Project Online Professional - Flow for Project Online' }
        PROJECTPROFESSIONAL_PROJECT_CLIENT_SUBSCRIPTION { 'Project Online Professional - Project Online Desktop Client' }
        PROJECTPROFESSIONAL_PROJECT_PROFESSIONAL { 'Project Online Professional - Project Professional' }
        PROJECTPROFESSIONAL_SHAREPOINT_PROJECT { 'Project Online Professional - Project Online Service' }
        PROJECTPROFESSIONAL_SHAREPOINTENTERPRISE { 'Project Online Professional - SharePoint (P2)' }
        PROJECTPROFESSIONAL_SHAREPOINTWAC { 'Project Online Professional - Office for web' }
        PROJECTWORKMANAGEMENT { 'Microsoft Planner' }
        RECORDS_MANAGEMENT { 'Microsoft Records Management' }
        RIGHTSMANAGEMENT { 'Azure Information Protection Plan 1' }
        RIGHTSMANAGEMENT_ADHOC { 'Rights Management Adhoc' }
        RIGHTSMANAGEMENT_ADHOC_RMS_S_ADHOC { 'Rights Management Adhoc' }
        RIGHTSMANAGEMENT_FACULTY { 'Azure Active Directory Rights for Faculty' }
        RIGHTSMANAGEMENT_GOV { 'Azure Active Directory Rights for Government' }
        RIGHTSMANAGEMENT_RMS_S_ENTERPRISE { 'Azure Information Protection Plan 1 - Microsoft Azure AD Rights' }
        RIGHTSMANAGEMENT_RMS_S_PREMIUM { 'Azure Information Protection Plan 1 - Azure Information Protection Premium P1' }
        RIGHTSMANAGEMENT_RMS_S_PREMIUM2 { 'Azure Information Protection Plan 1 - Azure Information Protection Premium P2' }
        RIGHTSMANAGEMENT_STANDARD_FACULTY { 'Azure Rights Management for faculty' }
        RIGHTSMANAGEMENT_STANDARD_STUDENT { 'Azure Rights Management for students' }
        RIGHTSMANAGEMENT_STUDENT { 'Azure Active Directory Rights for Students' }
        RMS_S_ADHOC { 'Rights Management Adhoc' }
        RMS_S_ENTERPRISE { 'Microsoft Azure Active Directory Rights' }
        RMS_S_ENTERPRISE_GOV { 'Azure Rights Management' }
        RMS_S_PREMIUM { 'Azure Information Protection Premium P1' }
        RMS_S_PREMIUM2 { 'Azure Information Protection Premium P2' }
        RMSBASIC { 'Rights Management Basic' }
        SAFEDOCS { 'Office 365 Safedocs' }
        SCHOOL_DATA_SYNC_P1 { 'School Data Sync (Plan 1)' }
        SCHOOL_DATA_SYNC_P2 { 'School Data Sync (Plan 2)' }
        SHAREPOINT_PROJECT { 'Project Online Service' }
        SHAREPOINT_PROJECT_EDU { 'Project Online for Education' }
        SHAREPOINT_S_DEVELOPER { 'SHAREPOINT_S_DEVELOPER' }
        SHAREPOINTDESKLESS { 'Sharepoint Online Kiosk' }
        SHAREPOINTDESKLESS_GOV { 'SharePoint Online Kiosk' }
        SHAREPOINTDESKLESS_SHAREPOINTDESKLESS { 'Sharepoint Online Kiosk - Sharepoint Online Kiosk' }
        SHAREPOINTENTERPRISE { 'Sharepoint Online (Plan 2)' }
        SHAREPOINTENTERPRISE_EDU { 'Sharepoint Plan 2 for EDU' }
        SHAREPOINTENTERPRISE_FACULTY { 'SharePoint (Plan 2 for Faculty)' }
        SHAREPOINTENTERPRISE_GOV { 'SharePoint P2 for Government' }
        SHAREPOINTENTERPRISE_SHAREPOINTENTERPRISE { 'Sharepoint Online (Plan 2)' }
        SHAREPOINTENTERPRISE_STUDENT { 'SharePoint (Plan 2 for Students)' }
        SHAREPOINTENTERPRISE_YAMMER { 'SharePoint (Plan 2 with Yammer)' }
        SHAREPOINTLITE { 'Sharepointlite' }
        SHAREPOINTPARTNER { 'SharePoint Online Partner Access' }
        SHAREPOINTSTANDARD { 'Sharepoint Online (Plan 1)' }
        SHAREPOINTSTANDARD_EDU { 'SharePoint Plan 1 for EDU' }
        SHAREPOINTSTANDARD_FACULTY { 'SharePoint (Plan 1 for Faculty)' }
        SHAREPOINTSTANDARD_GOV { 'SharePoint for Government (Plan 1G)' }
        SHAREPOINTSTANDARD_SHAREPOINTSTANDARD { 'Sharepoint Online (Plan 1)' }
        SHAREPOINTSTANDARD_STUDENT { 'SharePoint (Plan 1 for Students)' }
        SHAREPOINTSTANDARD_YAMMER { 'SharePoint (Plan 1 with Yammer)' }
        SHAREPOINTSTORAGE { 'SharePoint Online Storage' }
        SHAREPOINTWAC { 'Office Online' }
        SHAREPOINTWAC_DEVELOPER { 'Office Online for Developer' }
        SHAREPOINTWAC_EDU { 'Office for The Web (Education)' }
        SHAREPOINTWAC_GOV { 'Office Online for Government' }
        SKUID { 'Product Name' }
        SKU_Dynamics_365_for_HCM_Trial { 'Dynamics 365 for Talents' }
        SKU_DYNAMICS_365_FOR_HCM_TRIAL_DYN365_CDS_DYN_APPS { 'Dynamics 365 for Talents' }
        SKU_DYNAMICS_365_FOR_HCM_TRIAL_DYNAMICS_365_FOR_HCM_TRIAL { 'Dynamics 365 for Talents' }
        SKU_DYNAMICS_365_FOR_HCM_TRIAL_DYNAMICS_365_HIRING_FREE_PLAN { 'Dynamics 365 for Talents' }
        SKU_DYNAMICS_365_FOR_HCM_TRIAL_DYNAMICS_365_ONBOARDING_FREE_PLAN { 'Dynamics 365 for Talents' }
        SKU_DYNAMICS_365_FOR_HCM_TRIAL_FLOW_DYN_APPS { 'Dynamics 365 for Talents - Flow for Dynamics 365' }
        SKU_DYNAMICS_365_FOR_HCM_TRIAL_POWERAPPS_DYN_APPS { 'Dynamics 365 for Talents' }
        SMB_APPS { 'Microsoft Business Apps' }
        SMB_APPS_DYN365BC_MS_INVOICING { 'Microsoft Business Apps - Microsoft Invoicing' }
        SMB_APPS_MICROSOFTBOOKINGS { 'Microsoft Business Apps - Microsoft Bookings' }
        SMB_BUSINESS { 'Microsoft 365 Apps for Business' }
        SMB_BUSINESS_ESSENTIALS { 'Microsoft 365 Business Basic' }
        SMB_BUSINESS_ESSENTIALS_EXCHANGE_S_STANDARD { 'M365 Business Basic - Exchange Online (P2)' }
        SMB_BUSINESS_ESSENTIALS_FLOW_O365_P1 { 'M365 Business Basic - Flow for Office 365' }
        SMB_BUSINESS_ESSENTIALS_FORMS_PLAN_E1 { 'M365 Business Basic - Microsft Forms (Plan E1)' }
        SMB_BUSINESS_ESSENTIALS_MCOSTANDARD { 'M365 Business Basic - Skype for Business Online (P2)' }
        SMB_BUSINESS_ESSENTIALS_POWERAPPS_O365_P1 { 'M365 Business Basic - PowerApps for Office 365' }
        SMB_BUSINESS_ESSENTIALS_PROJECTWORKMANAGEMENT { 'M365 Business Basic - Microsoft Planner' }
        SMB_BUSINESS_ESSENTIALS_SHAREPOINTSTANDARD { 'M365 Business Basic - SharePoint (P1)' }
        SMB_BUSINESS_ESSENTIALS_SHAREPOINTWAC { 'M365 Business Basic - Office for web' }
        SMB_BUSINESS_ESSENTIALS_SWAY { 'M365 Business Basic - Sway' }
        SMB_BUSINESS_ESSENTIALS_TEAMS1 { 'M365 Business Basic - Microsoft Teams' }
        SMB_BUSINESS_ESSENTIALS_YAMMER_MIDSIZE { 'M365 Business Basic - Yammer Enterprise' }
        SMB_BUSINESS_FORMS_PLAN_E1 { 'M365 Apps for Business - Microsft Forms (Plan E1)' }
        SMB_BUSINESS_OFFICE_BUSINESS { 'M365 Apps for Business - Office 365 Business' }
        SMB_BUSINESS_ONEDRIVESTANDARD { 'M365 Apps for Business - OneDrive for Business' }
        SMB_BUSINESS_PREMIUM { 'Microsoft 365 Business Standard' }
        SMB_BUSINESS_PREMIUM_EXCHANGE_S_STANDARD { 'M365 Business Standard - Exchange Online (P2)' }
        SMB_BUSINESS_PREMIUM_FLOW_O365_P1 { 'M365 Business Standard - Flow for Office 365' }
        SMB_BUSINESS_PREMIUM_FORMS_PLAN_E1 { 'M365 Business Standard - Microsft Forms (Plan E1)' }
        SMB_BUSINESS_PREMIUM_MCOSTANDARD { 'M365 Business Standard - Skype for Business Online (P2)' }
        SMB_BUSINESS_PREMIUM_MICROSOFTBOOKINGS { 'M365 Business Standard - Microsoft Bookings' }
        SMB_BUSINESS_PREMIUM_O365_SB_RELATIONSHIP_MANAGEMENT { 'M365 Business Standard -' }
        SMB_BUSINESS_PREMIUM_OFFICE_BUSINESS { 'M365 Business Standard - Office 365 Business' }
        SMB_BUSINESS_PREMIUM_POWERAPPS_O365_P1 { 'M365 Business Standard - PowerApps for Office 365' }
        SMB_BUSINESS_PREMIUM_PROJECTWORKMANAGEMENT { 'M365 Business Standard - Microsoft Planner' }
        SMB_BUSINESS_PREMIUM_SHAREPOINTSTANDARD { 'M365 Business Standard - SharePoint (P1)' }
        SMB_BUSINESS_PREMIUM_SHAREPOINTWAC { 'M365 Business Standard - Office for web' }
        SMB_BUSINESS_PREMIUM_SWAY { 'M365 Business Standard - Sway' }
        SMB_BUSINESS_PREMIUM_TEAMS1 { 'M365 Business Standard - Microsoft Teams' }
        SMB_BUSINESS_PREMIUM_YAMMER_MIDSIZE { 'M365 Business Standard - Yammer Enterprise' }
        SMB_BUSINESS_SHAREPOINTWAC { 'M365 Apps for Business - Office for web' }
        SMB_BUSINESS_SWAY { 'M365 Apps for Business - Sway' }
        SOCIAL_ENGAGEMENT_APP_USER { 'Dynamics 365 AI for Market Insights' }
        SPB { 'Microsoft 365 Business Premium' }
        SPE_E3 { 'Microsoft 365 E3' }
        SPE_E3_USGOV_DOD { 'Microsoft 365 E3_USGOV_DOD' }
        SPE_E3_USGOV_GCCHIGH { 'Microsoft 365 E3_USGOV_GCCHIGH' }
        SPE_E5 { 'Microsoft 365 E5' }
        SPE_F1 { 'Microsoft 365 F3' }
        SPE_F1_AAD_PREMIUM { 'M365 F1 - Azure AD Premium P1' }
        SPE_F1_ADALLOM_S_DISCOVERY { 'M365 F1 - Cloud App Security Discovery' }
        SPE_F1_BPOS_S_TODO_FIRSTLINE { 'M365 F1 - To-do (Firstline)' }
        SPE_F1_DESKLESS { 'M365 F1 - Microsoft Staffhub' }
        SPE_F1_DYN365_CDS_O365_F1 { 'M365 F1 - Common Data Service' }
        SPE_F1_EXCHANGE_S_DESKLESS { 'M365 F1 - Exchange Online Kiosk' }
        SPE_F1_FLOW_O365_S1 { 'M365 F1 - Flow for Office 365 K1' }
        SPE_F1_FORMS_PLAN_K { 'M365 F1 - Microsoft Forms (Plan F1)' }
        SPE_F1_INTUNE_A { 'M365 F1 - Microsoft Intune' }
        SPE_F1_KAIZALA_O365_P1 { 'M365 F1 - Microsoft Kaizala' }
        SPE_F1_MCOIMP { 'M365 F1 - Skype for Business Online (P1)' }
        SPE_F1_MFA_PREMIUM { 'M365 F1 - Azure Multi-factor Authentication' }
        SPE_F1_OFFICEMOBILE_SUBSCRIPTION { 'M365 F1 - Office Mobile Apps for Office 365' }
        SPE_F1_POWERAPPS_O365_S1 { 'M365 F1 - Powerapps for Office 365 K1' }
        SPE_F1_PROJECTWORKMANAGEMENT { 'M365 F1 - Microsoft Planner' }
        SPE_F1_RMS_S_ENTERPRISE { 'M365 F1 - Azure Rights Management' }
        SPE_F1_RMS_S_PREMIUM { 'M365 F1 - Azure Information Protection P1' }
        SPE_F1_SHAREPOINTDESKLESS { 'M365 F1 - Sharepoint Online Kiosk' }
        SPE_F1_SHAREPOINTWAC { 'M365 F1 - Office for web' }
        SPE_F1_STREAM_O365_K { 'M365 F1 - Microsoft Stream for O365 K SKU' }
        SPE_F1_SWAY { 'M365 F1 - Sway' }
        SPE_F1_TEAMS1 { 'M365 F1 - Microsoft Teams' }
        SPE_F1_WHITEBOARD_FIRSTLINE1 { 'M365 F1 - Whiteboard (Firstline)' }
        SPE_F1_WIN10_ENT_LOC_F1 { 'M365 F1 - Windows 10 Enterprise E3 (local Only)' }
        SPE_F1_YAMMER_ENTERPRISE { 'M365 F1 - Yammer Enterprise' }
        SPZA { 'App Connect' }
        SPZA_IW { 'App Connect' }
        SPZA_IW_SPZA { 'App Connect Iw' }
        SQL_IS_SSIM { 'Microsoft Power BI Information Services Plan 1' }
        STANDARD_B_PILOT { 'Office 365 (Small Business Preview)' }
        STANDARDPACK { 'Office 365 E1' }
        STANDARDPACK_BPOS_S_TODO_1 { 'O365 E1 - To-do (P1)' }
        STANDARDPACK_DESKLESS { 'O365 E1 - Microsoft StaffHub' }
        STANDARDPACK_DYN365_CDS_O365_P1 { 'O365 E1 - Common Data Service' }
        STANDARDPACK_EXCHANGE_S_STANDARD { 'O365 E1 - Exchange Online (P2)' }
        STANDARDPACK_FACULTY { 'Office 365 Education E1 for Faculty' }
        STANDARDPACK_FLOW_O365_P1 { 'O365 E1 - Flow for Office 365' }
        STANDARDPACK_FORMS_PLAN_E1 { 'O365 E1 - Microsft Forms (Plan E1)' }
        STANDARDPACK_GOV { 'Office 365 Enterprise E1 for Government' }
        STANDARDPACK_KAIZALA_O365_P2 { 'O365 E1 - Microsoft Kaizala Pro' }
        STANDARDPACK_MCOSTANDARD { 'O365 E1 - Skype for Business Online (P2)' }
        STANDARDPACK_MYANALYTICS_P2 { 'O365 E1 - Insights by MyAnalytics' }
        STANDARDPACK_OFFICEMOBILE_SUBSCRIPTION { 'O365 E1 - Office Mobile Apps for Office 365' }
        STANDARDPACK_POWERAPPS_O365_P1 { 'O365 E1 - PowerApps for Office 365' }
        STANDARDPACK_PROJECTWORKMANAGEMENT { 'O365 E1 - Microsoft Planner' }
        STANDARDPACK_SHAREPOINTSTANDARD { 'O365 E1 - SharePoint (P1)' }
        STANDARDPACK_SHAREPOINTWAC { 'O365 E1 - Office for web' }
        STANDARDPACK_STREAM_O365_E1 { 'O365 E1 - Microsoft Stream for O365 E1 SKU' }
        STANDARDPACK_STUDENT { 'Office 365 Education E1 for Students' }
        STANDARDPACK_SWAY { 'O365 E1 - Sway' }
        STANDARDPACK_TEAMS1 { 'O365 E1 - Microsoft Teams' }
        STANDARDPACK_WHITEBOARD_PLAN1 { 'O365 E1 - Whiteboard (P1)' }
        STANDARDPACK_YAMMER_ENTERPRISE { 'O365 E1 - Yammer Enterprise' }
        STANDARDWOFFPACK { 'Office 365 E2' }
        STANDARDWOFFPACK_DESKLESS { 'O365 E2 - Microsoft StaffHub' }
        STANDARDWOFFPACK_EXCHANGE_S_STANDARD { 'O365 E2 - Exchange Online (P2)' }
        STANDARDWOFFPACK_FACULTY { 'Office 365 A1 for faculty' }
        STANDARDWOFFPACK_FLOW_O365_P1 { 'O365 E2 - Flow for Office 365' }
        STANDARDWOFFPACK_FORMS_PLAN_E1 { 'O365 E2 - Microsft Forms (Plan E1)' }
        STANDARDWOFFPACK_GOV { 'Office 365 Enterprise E2 for Government' }
        STANDARDWOFFPACK_IW_FACULTY { 'Office 365 Education E2 for Faculty' }
        STANDARDWOFFPACK_IW_STUDENT { 'Office 365 Education E2 for Students' }
        STANDARDWOFFPACK_MCOSTANDARD { 'O365 E2 - Skype for Business Online (P2)' }
        STANDARDWOFFPACK_POWERAPPS_O365_P1 { 'O365 E2 - PowerApps for Office 365' }
        STANDARDWOFFPACK_PROJECTWORKMANAGEMENT { 'O365 E2 - Microsoft Planner' }
        STANDARDWOFFPACK_SHAREPOINTSTANDARD { 'O365 E2 - SharePoint (P1)' }
        STANDARDWOFFPACK_SHAREPOINTWAC { 'O365 E2 - Office for web' }
        STANDARDWOFFPACK_STREAM_O365_E1 { 'O365 E2 - Stream for Office 365' }
        STANDARDWOFFPACK_STUDENT { 'Office 365 A1 for students' }
        STANDARDWOFFPACK_SWAY { 'O365 E2 - Sway' }
        STANDARDWOFFPACK_TEAMS1 { 'O365 E2 - Microsoft Teams' }
        STANDARDWOFFPACK_YAMMER_ENTERPRISE { 'O365 E2 - Yammer Enterprise' }
        STANDARDWOFFPACKPACK_FACULTY { 'Office 365 Plan A2 for Faculty' }
        STANDARDWOFFPACKPACK_STUDENT { 'Office 365 Plan A2 for Students' }
        STREAM { 'Microsoft Stream Trial' }
        STREAM_MICROSOFTSTREAM { 'Microsoft Stream Trial' }
        STREAM_O365_E1 { 'Microsoft Stream for O365 E1 SKU' }
        STREAM_O365_E3 { 'Microsoft Stream for O365 E3 SKU' }
        STREAM_O365_E5 { 'Microsoft Stream for O365 E5 SKU' }
        STREAM_O365_K { 'Microsoft Stream for O365 K SKU' }
        SWAY { 'Sway' }
        TEAMS_AR_DOD { 'Microsoft Teams for DoD (ar)' }
        TEAMS_AR_GCCHIGH { 'Microsoft Teams for GCC High (ar)' }
        TEAMS_COMMERCIAL_TRIAL_FLOW_O365_P1 { 'Microsoft Teams Commercial Cloud - Flow for Office 365' }
        TEAMS_COMMERCIAL_TRIAL_FORMS_PLAN_E1 { 'Microsoft Teams Commercial Cloud - Microsoft Forms (P1)' }
        TEAMS_COMMERCIAL_TRIAL_MCO_TEAMS_IW { 'Microsoft Teams Commercial Cloud - Microsoft Teams' }
        TEAMS_COMMERCIAL_TRIAL_POWERAPPS_O365_P1 { 'Microsoft Teams Commercial Cloud - PowerApps for Office 365' }
        TEAMS_COMMERCIAL_TRIAL_PROJECTWORKMANAGEMENT { 'Microsoft Teams Commercial Cloud - Microsoft Planner' }
        TEAMS_COMMERCIAL_TRIAL_SHAREPOINTDESKLESS { 'Microsoft Teams Commercial Cloud - SharePoint Kiosk' }
        TEAMS_COMMERCIAL_TRIAL_SHAREPOINTWAC { 'Microsoft Teams Commercial Cloud - Office for the web' }
        TEAMS_COMMERCIAL_TRIAL_STREAM_O365_E1 { 'Microsoft Teams Commercial Cloud - Microsoft Stream for O365 E1 SKU' }
        TEAMS_COMMERCIAL_TRIAL_SWAY { 'Microsoft Teams Commercial Cloud - Sway' }
        TEAMS_COMMERCIAL_TRIAL_TEAMS1 { 'Microsoft Teams Commercial Cloud - Microsoft Teams' }
        TEAMS_COMMERCIAL_TRIAL_WHITEBOARD_PLAN1 { 'Microsoft Teams Commercial Cloud - Whiteboard (P1)' }
        TEAMS_COMMERCIAL_TRIAL_YAMMER_ENTERPRISE { 'Microsoft Teams Commercial Cloud - Yammer Enterprise' }
        TEAMS_EXPLORATORY { 'Teams Exploratory Trial' }
        TEAMS_FREE { 'Microsoft Teams (Free)' }
        TEAMS1 { 'Microsoft Teams' }
        THREAT_INTELLIGENCE { 'Office 365 Advanced Threat Protection (Plan 2)' }
        TOPIC_EXPERIENCES { 'Topic Experiences' }
        UNIVERSAL_PRINT_M365 { 'Universal Print' }
        UNIVERSAL_PRINT_EDU_M365 { 'Universal Print for Education Trial' }
        TrialDYN365_AI_SERVICE_INSIGHTS { 'Dynamics 365 Customer Service Insights' }
        VIDEO_INTEROP { 'Polycom Skype Meeting Video Interop for Skype for Business' }
        VIDEO_INTEROP_VIDEO_INTEROP { 'Polycom Skype Meeting Video Interop for Skype for Business' }
        #$VirtualizationRightsforWindows10(E3/E5+VDA) { 'Windows 10 Enterprise (new)' }
        VISIO_CLIENT_SUBSCRIPTION { 'Visio Online' }
        VISIOCLIENT { 'Visio Online Plan 2' }
        VISIOCLIENT_FACULTY { 'Visio Pro for Office 365 for Faculty' }
        VISIOCLIENT_GOV { 'Visio Pro for Office 365 for Government' }
        VISIOCLIENT_ONEDRIVE_BASIC { 'Visio Online P2 - OneDrive Basic' }
        VISIOCLIENT_STUDENT { 'Visio Pro for Office 365 for Students' }
        VISIOCLIENT_VISIO_CLIENT_SUBSCRIPTION { 'Visio Online P2 - Visio Online Desktop Client' }
        VISIOCLIENT_VISIOONLINE { 'Visio Online P2 - Vision Online' }
        VISIOONLINE { 'Visioonline' }
        VISIOONLINE_PLAN1 { 'Visio Online Plan 1' }
        VISIOONLINE_PLAN1_ONEDRIVE_BASIC { 'Visio Online P1 - OneDrive Basic' }
        VISIOONLINE_PLAN1_VISIOONLINE { 'Visio Online P1 - Visio Online' }
        WACONEDRIVEENTERPRISE { 'Onedrive for Business (Plan 2)' }
        WACONEDRIVEENTERPRISE_ONEDRIVEENTERPRISE { 'Onedrive for Business (P2) - OneDrive for Business P2' }
        WACONEDRIVEENTERPRISE_SHAREPOINTWAC { 'Onedrive for Business (P2) - Office for web' }
        WACONEDRIVESTANDARD { 'Onedrive for Business (Plan 1)' }
        WACONEDRIVESTANDARD_FORMS_PLAN_E1 { 'Onedrive for Business (P1) - Microsft Forms (Plan E1)' }
        WACONEDRIVESTANDARD_GOV { 'OneDrive for Business with Office Web Apps for Government' }
        WACONEDRIVESTANDARD_ONEDRIVESTANDARD { 'Onedrive for Business (P1) - OneDrive for Business' }
        WACONEDRIVESTANDARD_SHAREPOINTWAC { 'Onedrive for Business (P1) - Office for web' }
        WACONEDRIVESTANDARD_SWAY { 'Onedrive for Business (P1) - Sway' }
        WACSHAREPOINTENT { 'Office Web Apps with SharePoint Plan 2' }
        WACSHAREPOINTENT_FACULTY { 'Office Web Apps (Plan 2 For Faculty)' }
        WACSHAREPOINTENT_GOV { 'Office Web Apps (Plan 2G for Government)' }
        WACSHAREPOINTENT_STUDENT { 'Office Web Apps (Plan 2 For Students)' }
        WACSHAREPOINTSTD { 'Office Online' }
        WACSHAREPOINTSTD_FACULTY { 'Office Web Apps (Plan 1 For Faculty)' }
        WACSHAREPOINTSTD_GOV { 'Office Web Apps (Plan 1G for Government)' }
        WACSHAREPOINTSTD_STUDENT { 'Office Web Apps (Plan 1 For Students)' }
        WHITEBOARD_FIRSTLINE1 { 'Whiteboard (Firstline)' }
        WHITEBOARD_PLAN2 { 'Whiteboard (Plan 2)' }
        WHITEBOARD_PLAN3 { 'Whiteboard (Plan 3)' }
        WIN_DEF_ATP { 'Microsoft Defender Advanced Threat Protection' }
        WIN_DEF_ATP_WINDEFATP { 'Microsoft Defender Advanced Threat Protection' }
        WIN10_ENT_LOC_F1 { 'Windows 10 Enterprise E3 (local Only)' }
        WIN10_PRO_ENT_SUB { 'Windows 10 Enterprise E3' }
        WIN10_PRO_ENT_SUB_WIN10_PRO_ENT_SUB { 'Windows 10 Enterprise E3' }
        WIN10_VDA_E3 { 'Windows 10 Enterprise E3' }
        #WIN10_VDA_E3_VIRTUALIZATIONRIGHTSFORWINDOWS10 (E3/E5+VDA) { 'Windows 10 Enterprise E3 - Windows 10 Enterprise' }
        WIN10_VDA_E5 { 'Windows 10 Enterprise E5' }
        #WIN10_VDA_E5_VIRTUALIZATIONRIGHTSFORWINDOWS10 (E3/E5+VDA) { 'Windows 10 Enterprise E5 - Windows 10 Enterprise' }
        WIN10_VDA_E5_WINDEFATP { 'Windows 10 Enterprise E5 - Microsoft Defender Advanced Threat Protection' }
        WINBIZ { 'Windows 10 Business' }
        WINDEFATP { 'Microsoft Defender Advanced Threat Protection' }
        WINDOWS_STORE { 'Windows Store Service' }
        WORKPLACE_ANALYTICS { 'Microsoft Workplace Analytics' }
        WORKPLACE_ANALYTICS_WORKPLACE_ANALYTICS { 'Microsoft Workplace Analytics' }
        WSfB_EDU_Faculty { 'Windows Store for Business EDU Faculty' }
        YAMMER_EDU { 'Yammer for Academic' }
        YAMMER_ENTERPRISE { 'Yammer Enterprise' }
        YAMMER_ENTERPRISE_STANDALONE { 'Yammer Enterprise Standalone' }
        YAMMER_MIDSIZE { 'Yammer Midsize' }
              
    }
    $output = [PSCustomObject]@{
        DisplayName  = $mbx.DisplayName
        EmailAddress = $mbx.PrimarySMTPAddress
        License      = $License -join "; "
    }   

    $i++
    Write-Progress -Activity "Scanning Users for Office Licenses" -Status "Scaned: $i of $($Users.Count)" -PercentComplete (($i / $Users.Count) * 100)
    $output
}


#Output Configuration

#   Generate Name data
$Date = Get-Date
$Company = ((Get-MsolCompanyInformation | Select-Object InitialDomain).InitialDomain) -split "\." -replace "\." | Select-Object -First 1
$Name = ("Office365Licenses", $Company, $Date.Month, $Date.Day, $Date.Year, $Date.Second) -join "."
#   Save report to .CSV file
$Data | Sort-Object Name | Export-CSV -NoTypeInformation -Encoding UTF8 $ENV:TEMP\$Name.csv
#   Confirmation box
$title = 'Confirm'
$question = 'Do you want to open file in Excel?'
$choices = '&Yes', '&No'
$decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
#   Logic for Confirmation box
if ($decision -eq 0) {
    Write-Host "Opening in Excel..."
    Write-Host "The Report is located in $ENV:TEMP\OfficeUsersAndLicenses.csv"
    Start-Process Excel $ENV:TEMP\$Name.csv
}
else {
    Write-Host "The Report is located in $ENV:TEMP\OfficeUsersAndLicenses.csv"
}