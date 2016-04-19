SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL';

DROP DATABASE IF EXISTS `ToxReport_A`;

CREATE DATABASE `ToxReport_A`;

USE `ToxReport_A`;

DROP TABLE IF EXISTS `Species`;
DROP TABLE IF EXISTS `Homolog`;
DROP TABLE IF EXISTS `Gene`;
DROP TABLE IF EXISTS `Class_System`;
DROP TABLE IF EXISTS `Class`;
DROP TABLE IF EXISTS `Class_Parent`;
DROP TABLE IF EXISTS `Xref`;
DROP TABLE IF EXISTS `Gene_Class`;
DROP TABLE IF EXISTS `Class_Evid`;
DROP TABLE IF EXISTS `Annotation`;
DROP TABLE IF EXISTS `Names`;
DROP TABLE IF EXISTS `Tox_System`;
DROP TABLE IF EXISTS `ToxTerm`;
DROP TABLE IF EXISTS `ToxParent`;
DROP TABLE IF EXISTS `ToxLink`;
DROP TABLE IF EXISTS `ToxLink_Evid`;

-- -----------------------------------------------------
-- Table `Species`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `Species` (
  `idSpecies` INT NOT NULL AUTO_INCREMENT ,
  `ncbiTaxID` INT NOT NULL ,
  `commonName` VARCHAR(256) NOT NULL ,
  `sciName` TEXT NULL ,
  PRIMARY KEY (`idSpecies`) )
ENGINE = InnoDB
AUTO_INCREMENT = 1;


-- -----------------------------------------------------
-- Table `Homolog`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `Homolog` (
  `idHomolog` INT NOT NULL AUTO_INCREMENT ,
  `HomoloGene_ID` INT NOT NULL ,
  PRIMARY KEY (`idHomolog`) )
ENGINE = InnoDB
AUTO_INCREMENT = 1;


-- -----------------------------------------------------
-- Table `Gene`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `Gene` (
  `idGene` INT NOT NULL AUTO_INCREMENT ,
  `entrezID` INT NOT NULL ,
  `idSpecies` INT NOT NULL ,
  `GeneBook_ID` VARCHAR(45) NOT NULL DEFAULT 'N.A.' ,
  `idHomolog` INT NULL ,
  PRIMARY KEY (`idGene`) ,
  INDEX `fk_Gene_Species` (`idSpecies` ASC) ,
  INDEX `fk_Gene_Homolog` (`idHomolog` ASC) ,
  INDEX `idx_entrez` (`entrezID` ASC) ,
  INDEX `idx_genebook` (`GeneBook_ID` ASC) ,
  CONSTRAINT `fk_Gene_Species`
    FOREIGN KEY (`idSpecies` )
    REFERENCES `Species` (`idSpecies` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Gene_Homolog`
    FOREIGN KEY (`idHomolog` )
    REFERENCES `Homolog` (`idHomolog` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB
AUTO_INCREMENT = 1;


-- -----------------------------------------------------
-- Table `Class_System`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `Class_System` (
  `idClass_System` INT NOT NULL AUTO_INCREMENT ,
  `Class_Sys_Name` TEXT NOT NULL ,
  `Class_Sys_Desc` TEXT NULL ,
  PRIMARY KEY (`idClass_System`) )
ENGINE = InnoDB
AUTO_INCREMENT = 1;


-- -----------------------------------------------------
-- Table `Class`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `Class` (
  `idClass` INT NOT NULL AUTO_INCREMENT ,
  `idClass_System` INT NOT NULL ,
  `Class_Native_ID` VARCHAR(126) NOT NULL ,
  `Class_Name` TEXT NOT NULL ,
  `Class_Desc` TEXT NULL ,
  PRIMARY KEY (`idClass`, `idClass_System`) ,
  INDEX `fk_Class_Class_System` (`idClass_System` ASC) ,
  INDEX `idx_Class_Native_ID` (`Class_Native_ID` ASC) ,
  CONSTRAINT `fk_Class_Class_System`
    FOREIGN KEY (`idClass_System` )
    REFERENCES `Class_System` (`idClass_System` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB
AUTO_INCREMENT = 1
COMMENT = 'Generic classification of genes';


-- -----------------------------------------------------
-- Table `Class_Parent`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `Class_Parent` (
  `idClass_Parent` INT NOT NULL AUTO_INCREMENT ,
  `Parent_idClass` INT NOT NULL ,
  `Child_idClass` INT NOT NULL ,
  `Relationship` VARCHAR(256) NULL ,
  PRIMARY KEY (`idClass_Parent`, `Parent_idClass`, `Child_idClass`) ,
  INDEX `fk_Class_Parent_Class` (`Parent_idClass` ASC) ,
  INDEX `fk_Class_Parent_Class1` (`Child_idClass` ASC) ,
  CONSTRAINT `fk_Class_Parent_Class`
    FOREIGN KEY (`Parent_idClass` )
    REFERENCES `Class` (`idClass` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Class_Parent_Class1`
    FOREIGN KEY (`Child_idClass` )
    REFERENCES `Class` (`idClass` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB
AUTO_INCREMENT = 1
COMMENT = 'Links classes via parent to child relationship';


-- -----------------------------------------------------
-- Table `Xref`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `Xref` (
  `idXref` INT NOT NULL AUTO_INCREMENT ,
  `idGene` INT NOT NULL ,
  `Xref_Source` VARCHAR(45) NOT NULL ,
  `Xref_ID` TEXT NOT NULL ,
  PRIMARY KEY (`idXref`, `idGene`) ,
  INDEX `fk_Xref_Gene` (`idGene` ASC) ,
  CONSTRAINT `fk_Xref_Gene`
    FOREIGN KEY (`idGene` )
    REFERENCES `Gene` (`idGene` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB
AUTO_INCREMENT = 1;


-- -----------------------------------------------------
-- Table `Gene_Class`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `Gene_Class` (
  `idGene_Class` INT NOT NULL AUTO_INCREMENT ,
  `idGene` INT NOT NULL ,
  `idClass` INT NOT NULL ,
  PRIMARY KEY (`idGene_Class`, `idGene`, `idClass`) ,
  INDEX `fk_Gene_Class_Gene` (`idGene` ASC) ,
  INDEX `fk_Gene_Class_Class` (`idClass` ASC) ,
  CONSTRAINT `fk_Gene_Class_Gene`
    FOREIGN KEY (`idGene` )
    REFERENCES `Gene` (`idGene` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Gene_Class_Class`
    FOREIGN KEY (`idClass` )
    REFERENCES `Class` (`idClass` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB
AUTO_INCREMENT = 1;


-- -----------------------------------------------------
-- Table `Class_Evid`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `Class_Evid` (
  `idClass_Evid` INT NOT NULL AUTO_INCREMENT ,
  `idGene_Class` INT NOT NULL ,
  `Evid_Type` VARCHAR(45) NOT NULL ,
  `Evidence` TEXT NOT NULL ,
  `Evid_score` DOUBLE NULL ,
  `Create_Date` DATETIME NOT NULL ,
  `Update_Date` DATETIME NOT NULL ,
  PRIMARY KEY (`idClass_Evid`, `idGene_Class`) ,
  INDEX `fk_Class_Evid_Gene_Class` (`idGene_Class` ASC) ,
  CONSTRAINT `fk_Class_Evid_Gene_Class`
    FOREIGN KEY (`idGene_Class` )
    REFERENCES `Gene_Class` (`idGene_Class` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB
AUTO_INCREMENT = 1
COMMENT = 'Evidence linking gene to class';


-- -----------------------------------------------------
-- Table `Annotation`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `Annotation` (
  `idAnnotation` INT NOT NULL AUTO_INCREMENT ,
  `idGene` INT NOT NULL ,
  `Annot_Text` TEXT NOT NULL ,
  `Annot_Link` TEXT NULL ,
  `Create_Time` DATETIME NOT NULL ,
  PRIMARY KEY (`idAnnotation`, `idGene`) ,
  INDEX `fk_Annotation_Gene` (`idGene` ASC) ,
  CONSTRAINT `fk_Annotation_Gene`
    FOREIGN KEY (`idGene` )
    REFERENCES `Gene` (`idGene` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB
AUTO_INCREMENT = 1;


-- -----------------------------------------------------
-- Table `Names`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `Names` (
  `idNames` INT NOT NULL AUTO_INCREMENT ,
  `idGene` INT NOT NULL ,
  `Name` TEXT NOT NULL ,
  `Name_Type` VARCHAR(45) NOT NULL DEFAULT 'Alias' ,
  PRIMARY KEY (`idNames`, `idGene`) ,
  INDEX `fk_Names_Gene` (`idGene` ASC) ,
  CONSTRAINT `fk_Names_Gene`
    FOREIGN KEY (`idGene` )
    REFERENCES `Gene` (`idGene` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB
AUTO_INCREMENT = 1;


-- -----------------------------------------------------
-- Table `Tox_System`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `Tox_System` (
  `idTox_System` INT NOT NULL AUTO_INCREMENT ,
  `Tox_Sys_Name` TEXT NOT NULL ,
  `Tox_Sys_Desc` TEXT NULL ,
  PRIMARY KEY (`idTox_System`) )
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ToxTerm`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `ToxTerm` (
  `idToxTerm` INT NOT NULL AUTO_INCREMENT ,
  `idTox_System` INT NOT NULL ,
  `Tox_Native_ID` VARCHAR(45) NULL ,
  `Tox_Term` TEXT NOT NULL ,
  `Tox_Desc` TEXT NULL ,
  PRIMARY KEY (`idToxTerm`, `idTox_System`) ,
  INDEX `fk_ToxTerm_Tox_System` (`idTox_System` ASC) ,
  CONSTRAINT `fk_ToxTerm_Tox_System`
    FOREIGN KEY (`idTox_System` )
    REFERENCES `Tox_System` (`idTox_System` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ToxParent`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `ToxParent` (
  `idToxParent` INT NOT NULL AUTO_INCREMENT ,
  `Parent_idToxTerm` INT NOT NULL ,
  `Child_idToxTerm` INT NOT NULL ,
  `Relationship` VARCHAR(256) NULL ,
  PRIMARY KEY (`idToxParent`, `Parent_idToxTerm`, `Child_idToxTerm`) ,
  INDEX `fk_ToxParent_ToxTerm` (`Parent_idToxTerm` ASC) ,
  INDEX `fk_ToxParent_ToxTerm1` (`Child_idToxTerm` ASC) ,
  CONSTRAINT `fk_ToxParent_ToxTerm`
    FOREIGN KEY (`Parent_idToxTerm` )
    REFERENCES `ToxTerm` (`idToxTerm` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_ToxParent_ToxTerm1`
    FOREIGN KEY (`Child_idToxTerm` )
    REFERENCES `ToxTerm` (`idToxTerm` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ToxLink`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `ToxLink` (
  `idToxLink` INT NOT NULL AUTO_INCREMENT ,
  `idToxTerm` INT NOT NULL ,
  `Gene_idGene` INT NULL ,
  `Xref_idXref` INT NULL ,
  `Class_idClass` INT NULL ,
  PRIMARY KEY (`idToxLink`, `idToxTerm`) ,
  INDEX `fk_ToxLink_ToxTerm` (`idToxTerm` ASC) ,
  INDEX `fk_ToxLink_Xref` (`Xref_idXref` ASC) ,
  INDEX `fk_ToxLink_Class` (`Class_idClass` ASC) ,
  INDEX `fk_ToxLink_Gene` (`Gene_idGene` ASC) ,
  CONSTRAINT `fk_ToxLink_ToxTerm`
    FOREIGN KEY (`idToxTerm` )
    REFERENCES `ToxTerm` (`idToxTerm` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_ToxLink_Xref`
    FOREIGN KEY (`Xref_idXref` )
    REFERENCES `Xref` (`idXref` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_ToxLink_Class`
    FOREIGN KEY (`Class_idClass` )
    REFERENCES `Class` (`idClass` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_ToxLink_Gene`
    FOREIGN KEY (`Gene_idGene` )
    REFERENCES `Gene` (`idGene` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `ToxLink_Evid`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `ToxLink_Evid` (
  `idToxLink_Evid` INT NOT NULL AUTO_INCREMENT ,
  `idToxLink` INT NOT NULL ,
  `ToxEvid_Type` VARCHAR(45) NOT NULL ,
  `Tox_Evidence` TEXT NOT NULL ,
  `ToxEvid_Score` DOUBLE NULL ,
  `Create_Date` DATETIME NOT NULL ,
  `Update_Date` DATETIME NOT NULL ,
  PRIMARY KEY (`idToxLink_Evid`, `idToxLink`) ,
  INDEX `fk_ToxLink_Evid_ToxLink` (`idToxLink` ASC) ,
  CONSTRAINT `fk_ToxLink_Evid_ToxLink`
    FOREIGN KEY (`idToxLink` )
    REFERENCES `ToxLink` (`idToxLink` )
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;

-- -----------------------------------------------------
--        Create users and grant them access
-- -----------------------------------------------------
GRANT ALL ON TABLE `ToxReport_A`.* to 'ToxGene_Admin'@'%' IDENTIFIED BY 'ToxReporter_Admin';
GRANT ALL ON TABLE `ToxReport_A`.* to 'ToxGene_Admin'@'localhost' IDENTIFIED BY 'ToxReporter_Admin';

GRANT SELECT ON TABLE `ToxReport_A`.* to 'ToxGene_Guest'@'%' IDENTIFIED BY 'guest';
GRANT SELECT ON TABLE `ToxReport_A`.* to 'ToxGene_Guest'@'localhost' IDENTIFIED BY 'guest';
