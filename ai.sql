-- MySQL dump 10.13  Distrib 5.5.9, for Linux (x86_64)
--
-- Host: localhost    Database: admin_info
-- ------------------------------------------------------
-- Server version	5.5.9-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `islave_false`
--

DROP TABLE IF EXISTS `islave_false`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `islave_false` (
  `instance_id` int(11) unsigned NOT NULL,
  `isfalse` enum('Y','N') DEFAULT 'N',
  PRIMARY KEY (`instance_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `islave_instance`
--

DROP TABLE IF EXISTS `islave_instance`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `islave_instance` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `realm_id` int(11) DEFAULT NULL,
  `hostname` varchar(64) DEFAULT NULL,
  `ip` varchar(15) DEFAULT NULL,
  `active_schemas` varchar(256) DEFAULT NULL,
  `dbtype` varchar(16) DEFAULT NULL,
  `mysql_port` int(4) DEFAULT NULL,
  `notes` varchar(255) DEFAULT NULL,
  `monflag` enum('Y','N') NOT NULL DEFAULT 'Y',
  `created` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idu_ip-port` (`ip`,`mysql_port`),
  UNIQUE KEY `idu_hostname` (`hostname`,`mysql_port`),
  KEY `idx_realm` (`realm_id`)
) ENGINE=InnoDB AUTO_INCREMENT=166 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `islave_instance_raw`
--

DROP TABLE IF EXISTS `islave_instance_raw`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `islave_instance_raw` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `realm_id` int(11) DEFAULT NULL,
  `hostname` varchar(64) DEFAULT NULL,
  `ip` varchar(15) DEFAULT NULL,
  `schemas` varchar(128) DEFAULT NULL,
  `dbtype` varchar(16) DEFAULT NULL,
  `port` int(4) DEFAULT NULL,
  `notes` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=165 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `islave_notes`
--

DROP TABLE IF EXISTS `islave_notes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `islave_notes` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `instance_id` int(11) unsigned DEFAULT NULL,
  `poster` varchar(32) DEFAULT NULL,
  `note` varchar(256) DEFAULT NULL,
  `created` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `isactive` enum('Y','N') DEFAULT 'Y',
  PRIMARY KEY (`id`,`updated`)
) ENGINE=InnoDB AUTO_INCREMENT=32 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `islave_schema`
--

DROP TABLE IF EXISTS `islave_schema`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `islave_schema` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `schema_name` varchar(32) DEFAULT NULL,
  `notes` varchar(255) DEFAULT NULL,
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `modifed` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `islave_status`
--

DROP TABLE IF EXISTS `islave_status`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `islave_status` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `instance_id` int(11) DEFAULT NULL,
  `check_time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `notes` varchar(1024) DEFAULT NULL,
  `created` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `modified` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
  `realm_id` int(11) NOT NULL,
  `instance_type` varchar(32) NOT NULL,
  `masterip` varchar(16) DEFAULT NULL,
  `masterport` int(6) DEFAULT NULL,
  `secondsbehind` int(21) DEFAULT NULL,
  `iscurrent` int(1) DEFAULT '1',
  `check_time_date` date NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_iid` (`instance_id`),
  KEY `idx_rid` (`realm_id`),
  KEY `idx_iscurrent` (`iscurrent`),
  KEY `idx_date` (`check_time_date`)
) ENGINE=InnoDB AUTO_INCREMENT=1650889 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `realm`
--

DROP TABLE IF EXISTS `realm`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `realm` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'Primary key is just an incrementing ID.  This allows any column to change as needed.',
  `realm_name` varchar(100) NOT NULL COMMENT 'The name of the abbreviation for display purposes.',
  `realm_abbr` varchar(5) NOT NULL COMMENT 'The abbreviation used in reports and other places.  This should be less than five characters.',
  `realm_dimension_key` int(11) DEFAULT NULL COMMENT 'This is the foreign key link to the realm_dimension table.',
  `description` varchar(500) DEFAULT NULL COMMENT 'Any notes and comments about this shard/realm should be written here.',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=33 DEFAULT CHARSET=utf8 COMMENT='This table contains the realm information for any ETL.  Coup';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sc_instance`
--

DROP TABLE IF EXISTS `sc_instance`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sc_instance` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `ipaddr` varchar(16) NOT NULL,
  `ipaddrint` bigint(20) DEFAULT NULL,
  `hostname` varchar(32) DEFAULT NULL,
  `mysql_version_num` varchar(32) DEFAULT NULL,
  `mysql_version_int` bigint(20) DEFAULT NULL,
  `mysql_version_type` varchar(128) DEFAULT NULL,
  `mysql_version_comment` varchar(128) DEFAULT NULL,
  `mysql_version_arch` varchar(32) DEFAULT NULL,
  `mysql_version_os` varchar(32) DEFAULT NULL,
  `portnum` int(8) DEFAULT NULL,
  `subnet` varchar(16) DEFAULT NULL,
  `subnetint` bigint(20) DEFAULT NULL,
  `checkflag` enum('Y','N') DEFAULT 'Y',
  `notes` varchar(256) DEFAULT NULL,
  `modified` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idu_ip_port` (`ipaddr`,`portnum`),
  KEY `idx_subnet` (`subnet`),
  KEY `idx_subnetint` (`subnetint`)
) ENGINE=InnoDB AUTO_INCREMENT=687 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sc_mysql_version`
--

DROP TABLE IF EXISTS `sc_mysql_version`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sc_mysql_version` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `mysql_version` varchar(16) NOT NULL,
  `note` varchar(128) DEFAULT NULL,
  `num_instances` int(11) DEFAULT NULL,
  `modified` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idu_version` (`mysql_version`)
) ENGINE=InnoDB AUTO_INCREMENT=120 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sc_subnet`
--

DROP TABLE IF EXISTS `sc_subnet`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sc_subnet` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `subnet` varchar(15) NOT NULL,
  `addrclass` enum('A','B','C') NOT NULL DEFAULT 'C',
  `description` varchar(128) DEFAULT NULL,
  `subnetint` bigint(20) DEFAULT NULL,
  `updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=43 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `sc_variable`
--

DROP TABLE IF EXISTS `sc_variable`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sc_variable` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `iid` int(11) unsigned NOT NULL,
  `keyname` varchar(128) DEFAULT NULL,
  `val` text,
  `modified` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `idu_iid_keyname` (`iid`,`keyname`),
  KEY `idx_iid` (`iid`),
  KEY `idx_keyname` (`keyname`)
) ENGINE=InnoDB AUTO_INCREMENT=145496 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping routines for database 'admin_info'
--
/*!50003 DROP FUNCTION IF EXISTS `f_aton` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_AUTO_CREATE_USER' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50020 DEFINER=`rbyrd`@`10.%`*/ /*!50003 FUNCTION `f_aton`(a char(15)) RETURNS bigint(20)
    DETERMINISTIC
BEGIN
return inet_aton(a);
    END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2013-05-08 14:12:10
